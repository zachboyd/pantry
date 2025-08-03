import { describe, it, expect, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
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

  beforeEach(async () => {
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
});
