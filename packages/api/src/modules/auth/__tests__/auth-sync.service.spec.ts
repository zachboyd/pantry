import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { AuthSyncServiceImpl } from '../auth-sync.service.js';
import { TOKENS } from '../../../common/tokens.js';
import type { BetterAuthUser } from '../auth.types.js';
import {
  DatabaseMock,
  type KyselyMock,
} from '../../../test/utils/database-mock.js';

describe('AuthSyncService', () => {
  let authSyncService: AuthSyncServiceImpl;
  let mockDb: KyselyMock;
  let loggerSpy: {
    log: ReturnType<typeof vi.spyOn>;
    error: ReturnType<typeof vi.spyOn>;
    warn: ReturnType<typeof vi.spyOn>;
  };

  beforeEach(async () => {
    // Mock logger to avoid console output during tests
    loggerSpy = {
      log: vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {}),
      error: vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {}),
      warn: vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => {}),
    };

    // Create mock database using utility
    mockDb = DatabaseMock.createKyselyMock();
    mockDb.mockBuilder.mockExecuteTakeFirstOrThrow({ id: 'business-user-123' });

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        AuthSyncServiceImpl,
        {
          provide: TOKENS.DATABASE.CONNECTION,
          useValue: mockDb,
        },
      ],
    }).compile();

    authSyncService = module.get<AuthSyncServiceImpl>(AuthSyncServiceImpl);
  });

  describe('createBusinessUser', () => {
    it('should create business user record from auth user', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: 'John Doe',
        image: 'https://example.com/avatar.jpg',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert
      expect(mockDb.insertInto).toHaveBeenCalledWith('user');
      expect(mockDb.values).toHaveBeenCalledWith({
        id: expect.any(String), // UUID
        auth_user_id: 'auth-123',
        email: 'test@example.com',
        first_name: 'John',
        last_name: 'Doe',
        display_name: 'John Doe',
        avatar_url: 'https://example.com/avatar.jpg',
        created_at: expect.any(Date),
        updated_at: expect.any(Date),
      });
      expect(mockDb.returning).toHaveBeenCalledWith('id');
      expect(mockDb.executeTakeFirstOrThrow).toHaveBeenCalled();
    });

    it('should handle single name gracefully', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: 'Madonna',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert
      expect(mockDb.values).toHaveBeenCalledWith(
        expect.objectContaining({
          first_name: 'Madonna',
          last_name: '',
          display_name: 'Madonna',
        }),
      );
    });

    it('should handle multiple name parts correctly', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: 'Mary Jane Watson Smith',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert
      expect(mockDb.values).toHaveBeenCalledWith(
        expect.objectContaining({
          first_name: 'Mary',
          last_name: 'Jane Watson Smith',
          display_name: 'Mary Jane Watson Smith',
        }),
      );
    });

    it('should handle missing avatar gracefully', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: 'John Doe',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert
      expect(mockDb.values).toHaveBeenCalledWith(
        expect.objectContaining({
          avatar_url: null,
        }),
      );
    });

    it('should handle empty name gracefully without defaulting to "User"', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: '',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert - should NOT default first_name to 'User'
      expect(mockDb.values).toHaveBeenCalledWith(
        expect.objectContaining({
          first_name: '',
          last_name: '',
          display_name: '',
        }),
      );
    });

    it('should handle whitespace-only name gracefully without defaulting to "User"', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: '   ',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Act
      await authSyncService.createBusinessUser(authUser);

      // Assert - should NOT default first_name to 'User'
      expect(mockDb.values).toHaveBeenCalledWith(
        expect.objectContaining({
          first_name: '',
          last_name: '',
          display_name: '   ', // display_name preserves original
        }),
      );
    });

    it('should not throw on database errors', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'test@example.com',
        emailVerified: true,
        name: 'John Doe',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      // Mock database error
      mockDb.mockBuilder.mockError(new Error('DB Error'));

      // Act & Assert - should not throw
      await expect(
        authSyncService.createBusinessUser(authUser),
      ).resolves.toBeUndefined();
    });
  });

  describe('syncUserUpdate', () => {
    it('should sync all auth user fields to business user', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-123',
        email: 'updated@example.com',
        emailVerified: true,
        name: 'Jane Smith',
        image: 'https://example.com/avatar.jpg',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockDb.mockBuilder.mockExecuteTakeFirst({ numUpdatedRows: 1n });

      // Act
      await authSyncService.syncUserUpdate(authUser);

      // Assert
      expect(mockDb.updateTable).toHaveBeenCalledWith('user');
      expect(mockDb.set).toHaveBeenCalledWith({
        email: 'updated@example.com',
        first_name: 'Jane',
        last_name: 'Smith',
        display_name: 'Jane Smith',
        avatar_url: 'https://example.com/avatar.jpg',
        updated_at: expect.any(Date),
      });
      expect(mockDb.where).toHaveBeenCalledWith(
        'auth_user_id',
        '=',
        'auth-123',
      );
    });

    it('should handle null email and image fields', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-456',
        name: 'John Doe',
        emailVerified: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockDb.mockBuilder.mockExecuteTakeFirst({ numUpdatedRows: 1n });

      // Act
      await authSyncService.syncUserUpdate(authUser);

      // Assert
      expect(mockDb.set).toHaveBeenCalledWith({
        email: null,
        first_name: 'John',
        last_name: 'Doe',
        display_name: 'John Doe',
        avatar_url: null,
        updated_at: expect.any(Date),
      });
    });

    it('should handle single name correctly', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-789',
        email: 'single@example.com',
        emailVerified: true,
        name: 'Madonna',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockDb.mockBuilder.mockExecuteTakeFirst({ numUpdatedRows: 1n });

      // Act
      await authSyncService.syncUserUpdate(authUser);

      // Assert
      expect(mockDb.set).toHaveBeenCalledWith({
        email: 'single@example.com',
        first_name: 'Madonna',
        last_name: '', // Empty last name for single name
        display_name: 'Madonna',
        avatar_url: null,
        updated_at: expect.any(Date),
      });
    });

    it('should warn when no business user found', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-missing',
        email: 'missing@example.com',
        emailVerified: true,
        name: 'Missing User',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockDb.mockBuilder.mockExecuteTakeFirst({ numUpdatedRows: 0n });

      // Act
      await authSyncService.syncUserUpdate(authUser);

      // Assert
      expect(loggerSpy.warn).toHaveBeenCalledWith(
        expect.stringContaining(
          'No business user found for auth user auth-missing',
        ),
      );
    });

    it('should not throw on database errors during sync', async () => {
      // Arrange
      const authUser: BetterAuthUser = {
        id: 'auth-error',
        email: 'error@example.com',
        emailVerified: true,
        name: 'Error User',
        createdAt: new Date(),
        updatedAt: new Date(),
      };

      mockDb.mockBuilder.mockError(new Error('Sync DB Error'));

      // Act & Assert - should not throw
      await expect(
        authSyncService.syncUserUpdate(authUser),
      ).resolves.toBeUndefined();

      expect(loggerSpy.error).toHaveBeenCalledWith(
        expect.any(Error),
        expect.stringContaining('Failed to sync user update'),
      );
    });
  });
});
