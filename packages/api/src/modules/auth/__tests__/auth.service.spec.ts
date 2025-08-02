import { describe, it, expect, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import { AuthServiceImpl } from '../auth.service.js';
import { TOKENS } from '../../../common/tokens.js';
import type { AuthFactory } from '../auth.factory.js';
import {
  AuthFactoryMock,
  type AuthFactoryMockType,
} from '../../../test/mocks/auth-factory.mock.js';
import {
  BetterAuthInstanceMock,
  type BetterAuthInstanceMockType,
} from '../../../test/mocks/better-auth-instance.mock.js';

describe('AuthService', () => {
  let authService: AuthServiceImpl;
  let mockAuthFactory: AuthFactoryMockType;
  let mockAuthInstance: BetterAuthInstanceMockType;

  beforeEach(async () => {
    // Create mock auth instance using reusable mock factory
    mockAuthInstance = BetterAuthInstanceMock.createBetterAuthInstanceMock();

    // Create mock auth factory using reusable mock factory
    mockAuthFactory = AuthFactoryMock.createAuthFactoryMock(mockAuthInstance);

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        AuthServiceImpl,
        {
          provide: TOKENS.AUTH.FACTORY,
          useValue: mockAuthFactory as unknown as AuthFactory,
        },
      ],
    }).compile();

    authService = module.get<AuthServiceImpl>(AuthServiceImpl);
  });

  describe('verifySession', () => {
    it('should verify session with Headers object', async () => {
      // Arrange
      const headers = new Headers({
        cookie: 'session=abc123',
        authorization: 'Bearer token',
      });
      const expectedSession = {
        user: { id: 'user123', email: 'test@example.com' },
        session: { id: 'session123' },
      };

      mockAuthInstance.api.getSession.mockResolvedValue(expectedSession);

      // Act
      const result = await authService.verifySession(headers);

      // Assert
      expect(result).toEqual(expectedSession);
      expect(mockAuthFactory.createAuthInstance).toHaveBeenCalled();
      expect(mockAuthInstance.api.getSession).toHaveBeenCalledWith({
        headers: headers,
      });
    });

    it('should verify session with Record<string, string>', async () => {
      // Arrange
      const headersRecord = {
        cookie: 'session=abc123',
        'user-agent': 'Mozilla/5.0',
      };
      const expectedSession = {
        user: { id: 'user123', email: 'test@example.com' },
        session: { id: 'session123' },
      };

      mockAuthInstance.api.getSession.mockResolvedValue(expectedSession);

      // Act
      const result = await authService.verifySession(headersRecord);

      // Assert
      expect(result).toEqual(expectedSession);
      expect(mockAuthInstance.api.getSession).toHaveBeenCalledWith({
        headers: expect.any(Headers),
      });

      // Verify the Headers object was created correctly
      const [[{ headers: actualHeaders }]] =
        mockAuthInstance.api.getSession.mock.calls;
      expect(actualHeaders.get('cookie')).toBe('session=abc123');
      expect(actualHeaders.get('user-agent')).toBe('Mozilla/5.0');
    });

    it('should return null when session verification fails', async () => {
      // Arrange
      const headers = new Headers({ cookie: 'invalid=session' });

      mockAuthInstance.api.getSession.mockRejectedValue(
        new Error('Invalid session'),
      );

      // Act
      const result = await authService.verifySession(headers);

      // Assert
      expect(result).toBeNull();
      expect(mockAuthInstance.api.getSession).toHaveBeenCalledWith({
        headers: headers,
      });
    });

    it('should return null when auth instance throws error', async () => {
      // Arrange
      const headers = new Headers({ cookie: 'session=abc123' });

      mockAuthInstance.api.getSession.mockRejectedValue(
        new Error('Auth service unavailable'),
      );

      // Act
      const result = await authService.verifySession(headers);

      // Assert
      expect(result).toBeNull();
    });

    it('should reuse auth instance on subsequent calls', async () => {
      // Arrange
      const headers1 = new Headers({ cookie: 'session1=abc' });
      const headers2 = new Headers({ cookie: 'session2=def' });
      const session1 = { user: { id: 'user1' } };
      const session2 = { user: { id: 'user2' } };

      mockAuthInstance.api.getSession
        .mockResolvedValueOnce(session1)
        .mockResolvedValueOnce(session2);

      // Act
      await authService.verifySession(headers1);
      await authService.verifySession(headers2);

      // Assert
      expect(mockAuthFactory.createAuthInstance).toHaveBeenCalledTimes(1);
      expect(mockAuthInstance.api.getSession).toHaveBeenCalledTimes(2);
    });

    it('should handle empty headers gracefully', async () => {
      // Arrange
      const emptyHeaders = new Headers();

      mockAuthInstance.api.getSession.mockRejectedValue(
        new Error('No session cookie'),
      );

      // Act
      const result = await authService.verifySession(emptyHeaders);

      // Assert
      expect(result).toBeNull();
      expect(mockAuthInstance.api.getSession).toHaveBeenCalledWith({
        headers: emptyHeaders,
      });
    });

    it('should handle malformed cookies gracefully', async () => {
      // Arrange
      const headers = new Headers({ cookie: 'malformed-cookie-data' });

      mockAuthInstance.api.getSession.mockRejectedValue(
        new Error('Cookie parsing failed'),
      );

      // Act
      const result = await authService.verifySession(headers);

      // Assert
      expect(result).toBeNull();
    });

    it('should handle network errors gracefully', async () => {
      // Arrange
      const headers = new Headers({ cookie: 'session=abc123' });

      mockAuthInstance.api.getSession.mockRejectedValue(
        new Error('Network error'),
      );

      // Act
      const result = await authService.verifySession(headers);

      // Assert
      expect(result).toBeNull();
    });

    it('should convert various header formats correctly', async () => {
      // Arrange
      const complexHeaders = {
        'content-type': 'application/json',
        cookie: 'session=abc123; csrf=token456',
        authorization: 'Bearer jwt-token',
        'x-forwarded-for': '192.168.1.1',
      };
      const expectedSession = { user: { id: 'user123' } };

      mockAuthInstance.api.getSession.mockResolvedValue(expectedSession);

      // Act
      const result = await authService.verifySession(complexHeaders);

      // Assert
      expect(result).toEqual(expectedSession);

      // Verify Headers conversion
      const [[{ headers: actualHeaders }]] =
        mockAuthInstance.api.getSession.mock.calls;
      expect(actualHeaders.get('content-type')).toBe('application/json');
      expect(actualHeaders.get('cookie')).toBe('session=abc123; csrf=token456');
      expect(actualHeaders.get('authorization')).toBe('Bearer jwt-token');
      expect(actualHeaders.get('x-forwarded-for')).toBe('192.168.1.1');
    });
  });
});
