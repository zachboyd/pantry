import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import {
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { GuardedUserService } from '../guarded-user.service.js';
import { TOKENS } from '../../../../common/tokens.js';
import { DatabaseFixtures } from '../../../../test/fixtures/database-fixtures.js';
import { PermissionServiceMock } from '../../../../test/mocks/permission-service.mock.js';
import { UserServiceMock } from '../../../../test/mocks/user-service.mock.js';
import type { PermissionServiceMockType } from '../../../../test/mocks/permission-service.mock.js';
import type { UserServiceMockType } from '../../../../test/mocks/user-service.mock.js';

describe('GuardedUserService', () => {
  let service: GuardedUserService;
  let mockUserService: UserServiceMockType;
  let mockPermissionService: PermissionServiceMockType;

  beforeEach(async () => {
    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

    // Create reusable mocks
    mockUserService = UserServiceMock.createUserServiceMock();
    mockPermissionService = PermissionServiceMock.createPermissionServiceMock();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        GuardedUserService,
        {
          provide: TOKENS.USER.SERVICE,
          useValue: mockUserService,
        },
        {
          provide: TOKENS.PERMISSION.SERVICE,
          useValue: mockPermissionService,
        },
      ],
    }).compile();

    service = module.get<GuardedUserService>(GuardedUserService);
  });

  describe('updateUser', () => {
    it('should throw UnauthorizedException when user not authenticated', async () => {
      // Arrange
      const input = {
        id: 'test-user-id',
        first_name: 'Updated',
      };

      // Act & Assert
      await expect(service.updateUser(input, null)).rejects.toThrow(
        UnauthorizedException,
      );
      await expect(service.updateUser(input, null)).rejects.toThrow(
        'User must be authenticated',
      );
    });

    it('should throw NotFoundException when target user not found', async () => {
      // Arrange
      const input = {
        id: 'nonexistent-user-id',
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(null);

      // Act & Assert
      await expect(service.updateUser(input, currentUser)).rejects.toThrow(
        NotFoundException,
      );
      await expect(service.updateUser(input, currentUser)).rejects.toThrow(
        'User with ID nonexistent-user-id not found',
      );
      expect(mockUserService.getUserById).toHaveBeenCalledWith('nonexistent-user-id');
    });

    it('should allow user to update their own profile', async () => {
      // Arrange
      const input = {
        id: 'current-user-id',
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const existingUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Original',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(existingUser);
      mockUserService.updateUser = vi.fn().mockResolvedValue(updatedUser);

      // Act
      const result = await service.updateUser(input, currentUser);

      // Assert
      expect(result.user).toEqual(updatedUser);
      expect(mockUserService.getUserById).toHaveBeenCalledWith('current-user-id');
      expect(mockUserService.updateUser).toHaveBeenCalledWith('current-user-id', {
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display',
      });
      // Permission check should not be called for own profile
      expect(mockPermissionService.canViewUser).not.toHaveBeenCalled();
    });

    it('should filter out undefined values when updating own profile', async () => {
      // Arrange
      const input = {
        id: 'current-user-id',
        first_name: 'Updated',
        last_name: undefined,
        display_name: 'New Display',
        phone: undefined,
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const existingUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Updated',
        display_name: 'New Display',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(existingUser);
      mockUserService.updateUser = vi.fn().mockResolvedValue(updatedUser);

      // Act
      const result = await service.updateUser(input, currentUser);

      // Assert
      expect(result.user).toEqual(updatedUser);
      expect(mockUserService.updateUser).toHaveBeenCalledWith('current-user-id', {
        first_name: 'Updated',
        display_name: 'New Display',
      });
    });

    it('should check permissions when updating other users', async () => {
      // Arrange
      const input = {
        id: 'other-user-id',
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const targetUser = DatabaseFixtures.createUserResult({
        id: 'other-user-id',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(targetUser);
      mockPermissionService.canUpdateUser = vi.fn().mockResolvedValue(false);

      // Act & Assert
      await expect(service.updateUser(input, currentUser)).rejects.toThrow(
        ForbiddenException,
      );
      await expect(service.updateUser(input, currentUser)).rejects.toThrow(
        'You do not have permission to update this user',
      );
      expect(mockPermissionService.canUpdateUser).toHaveBeenCalledWith(
        'current-user-id',
        'other-user-id',
      );
    });

    it('should allow updating other users when user has permission', async () => {
      // Arrange
      const input = {
        id: 'other-user-id',
        first_name: 'Updated',
        phone: '+1234567890',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const targetUser = DatabaseFixtures.createUserResult({
        id: 'other-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'other-user-id',
        first_name: 'Updated',
        phone: '+1234567890',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(targetUser);
      mockPermissionService.canUpdateUser = vi.fn().mockResolvedValue(true);
      mockUserService.updateUser = vi.fn().mockResolvedValue(updatedUser);

      // Act
      const result = await service.updateUser(input, currentUser);

      // Assert
      expect(result.user).toEqual(updatedUser);
      expect(mockPermissionService.canUpdateUser).toHaveBeenCalledWith(
        'current-user-id',
        'other-user-id',
      );
      expect(mockUserService.updateUser).toHaveBeenCalledWith('other-user-id', {
        first_name: 'Updated',
        phone: '+1234567890',
      });
    });

    it('should handle service errors gracefully', async () => {
      // Arrange
      const input = {
        id: 'current-user-id',
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const existingUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(existingUser);
      mockUserService.updateUser = vi.fn().mockRejectedValue(new Error('Database error'));

      // Act & Assert
      await expect(service.updateUser(input, currentUser)).rejects.toThrow('Database error');
      expect(mockUserService.updateUser).toHaveBeenCalledWith('current-user-id', {
        first_name: 'Updated',
      });
    });

    it('should update user with all supported fields', async () => {
      // Arrange
      const input = {
        id: 'current-user-id',
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        birth_date: new Date('1990-01-01'),
        email: 'updated@example.com',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const existingUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        ...input,
      });

      mockUserService.getUserById = vi.fn().mockResolvedValue(existingUser);
      mockUserService.updateUser = vi.fn().mockResolvedValue(updatedUser);

      // Act
      const result = await service.updateUser(input, currentUser);

      // Assert
      expect(result.user).toEqual(updatedUser);
      expect(mockUserService.updateUser).toHaveBeenCalledWith('current-user-id', {
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        birth_date: new Date('1990-01-01'),
        email: 'updated@example.com',
      });
    });
  });
});