import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { UserServiceImpl } from '../user.service.js';
import { TOKENS } from '../../../common/tokens.js';
import type { User } from '../../../generated/database.js';
import type { Updateable } from 'kysely';
import {
  UserRepositoryMock,
  type UserRepositoryMockType,
} from '../../../test/mocks/user-repository.mock.js';
import { DatabaseFixtures } from '../../../test/fixtures/database-fixtures.js';

describe('UserService', () => {
  let userService: UserServiceImpl;
  let mockUserRepository: UserRepositoryMockType;

  beforeEach(async () => {
    // Create mocks
    mockUserRepository = UserRepositoryMock.createUserRepositoryMock();

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        UserServiceImpl,
        {
          provide: TOKENS.USER.REPOSITORY,
          useValue: mockUserRepository,
        },
      ],
    }).compile();

    userService = module.get<UserServiceImpl>(UserServiceImpl);

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  describe('getUserByAuthId', () => {
    it('should return user when found by auth_user_id', async () => {
      // Arrange
      const authUserId = 'test-auth-user-id';
      const expectedUser = DatabaseFixtures.createUserResult({
        auth_user_id: authUserId,
      });

      mockUserRepository.getUserByAuthId.mockResolvedValue(expectedUser);

      // Act
      const result = await userService.getUserByAuthId(authUserId);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockUserRepository.getUserByAuthId).toHaveBeenCalledWith(
        authUserId,
      );
    });

    it('should return null when user not found', async () => {
      // Arrange
      const authUserId = 'nonexistent-auth-user-id';
      mockUserRepository.getUserByAuthId.mockResolvedValue(null);

      // Act
      const result = await userService.getUserByAuthId(authUserId);

      // Assert
      expect(result).toBeNull();
      expect(mockUserRepository.getUserByAuthId).toHaveBeenCalledWith(
        authUserId,
      );
    });

    it('should log debug message when user not found', async () => {
      // Arrange
      const debugSpy = vi
        .spyOn(Logger.prototype, 'debug')
        .mockImplementation(() => {});
      const authUserId = 'nonexistent-auth-user-id';
      mockUserRepository.getUserByAuthId.mockResolvedValue(null);

      // Act
      await userService.getUserByAuthId(authUserId);

      // Assert
      expect(debugSpy).toHaveBeenCalledWith(
        `No user found for auth_user_id: ${authUserId}`,
      );
    });

    it('should handle database errors gracefully', async () => {
      // Arrange
      const authUserId = 'test-auth-user-id';
      const repositoryError = new Error('Repository connection failed');
      mockUserRepository.getUserByAuthId.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(userService.getUserByAuthId(authUserId)).rejects.toThrow(
        repositoryError,
      );
      expect(mockUserRepository.getUserByAuthId).toHaveBeenCalledWith(
        authUserId,
      );
    });

    it('should log errors when database operations fail', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const authUserId = 'test-auth-user-id';
      const repositoryError = new Error('Connection timeout');
      mockUserRepository.getUserByAuthId.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(userService.getUserByAuthId(authUserId)).rejects.toThrow();
      expect(errorSpy).toHaveBeenCalledWith(
        `Error getting user by auth ID ${authUserId}:`,
        repositoryError,
      );
    });
  });

  describe('getUserById', () => {
    it('should return user when found by id', async () => {
      // Arrange
      const userId = 'test-user-id';
      const expectedUser = DatabaseFixtures.createUserResult({
        id: userId,
      });

      mockUserRepository.getUserById.mockResolvedValue(expectedUser);

      // Act
      const result = await userService.getUserById(userId);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockUserRepository.getUserById).toHaveBeenCalledWith(userId);
    });

    it('should return null when user not found', async () => {
      // Arrange
      const userId = 'nonexistent-user-id';
      mockUserRepository.getUserById.mockResolvedValue(null);

      // Act
      const result = await userService.getUserById(userId);

      // Assert
      expect(result).toBeNull();
      expect(mockUserRepository.getUserById).toHaveBeenCalledWith(userId);
    });

    it('should log debug message when user not found', async () => {
      // Arrange
      const debugSpy = vi
        .spyOn(Logger.prototype, 'debug')
        .mockImplementation(() => {});
      const userId = 'nonexistent-user-id';
      mockUserRepository.getUserById.mockResolvedValue(null);

      // Act
      await userService.getUserById(userId);

      // Assert
      expect(debugSpy).toHaveBeenCalledWith(`No user found for id: ${userId}`);
    });

    it('should handle database errors gracefully', async () => {
      // Arrange
      const userId = 'test-user-id';
      const repositoryError = new Error('Repository connection failed');
      mockUserRepository.getUserById.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(userService.getUserById(userId)).rejects.toThrow(
        repositoryError,
      );
      expect(mockUserRepository.getUserById).toHaveBeenCalledWith(userId);
    });
  });

  describe('updateUser', () => {
    it('should update user and return updated data', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData: Updateable<User> = {
        first_name: 'Updated',
        last_name: 'Name',
        email: 'updated@example.com',
      };
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        first_name: 'Updated',
        last_name: 'Name',
        email: 'updated@example.com',
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      const result = await userService.updateUser(userId, updateData);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(
        userId,
        updateData,
      );
    });

    it('should log successful update', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const userId = 'test-user-id';
      const updateData: Updateable<User> = { first_name: 'Updated' };
      const updatedUser = DatabaseFixtures.createUserResult({ id: userId });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      await userService.updateUser(userId, updateData);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        `User updated successfully: ${userId}`,
      );
    });

    it('should handle database errors during update', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData: Updateable<User> = { first_name: 'Updated' };
      const repositoryError = new Error('Constraint violation');
      mockUserRepository.updateUser.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(userService.updateUser(userId, updateData)).rejects.toThrow(
        repositoryError,
      );
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(
        userId,
        updateData,
      );
    });

    it('should log errors when update fails', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const userId = 'test-user-id';
      const updateData: Updateable<User> = { first_name: 'Updated' };
      const repositoryError = new Error('User not found');
      mockUserRepository.updateUser.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(
        userService.updateUser(userId, updateData),
      ).rejects.toThrow();
      expect(errorSpy).toHaveBeenCalledWith(
        `Error updating user ${userId}:`,
        repositoryError,
      );
    });

    it('should handle partial user updates', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData: Updateable<User> = {
        display_name: 'New Display Name',
        phone: '+1234567890',
      };
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        display_name: 'New Display Name',
        phone: '+1234567890',
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      const result = await userService.updateUser(userId, updateData);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(
        userId,
        updateData,
      );
    });
  });

  describe('setPrimaryHousehold', () => {
    it('should successfully set primary household for user', async () => {
      // Arrange
      const userId = 'test-user-id';
      const householdId = 'test-household-id';
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        primary_household_id: householdId,
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      const result = await userService.setPrimaryHousehold(userId, householdId);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(userId, {
        primary_household_id: householdId,
      });
    });

    it('should log appropriate messages when setting primary household', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const userId = 'test-user-id';
      const householdId = 'test-household-id';
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        primary_household_id: householdId,
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      await userService.setPrimaryHousehold(userId, householdId);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        `Setting primary household ${householdId} for user ${userId}`,
      );
      expect(logSpy).toHaveBeenCalledWith(
        `Primary household set successfully for user ${userId}`,
      );

      logSpy.mockRestore();
    });

    it('should handle errors when setting primary household fails', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const userId = 'test-user-id';
      const householdId = 'test-household-id';
      const repositoryError = new Error('User not found');

      mockUserRepository.updateUser.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(
        userService.setPrimaryHousehold(userId, householdId),
      ).rejects.toThrow(repositoryError);

      expect(errorSpy).toHaveBeenCalledWith(
        `Error setting primary household for user ${userId}:`,
        repositoryError,
      );

      errorSpy.mockRestore();
    });

    it('should call repository with correct parameters', async () => {
      // Arrange
      const userId = 'user-123';
      const householdId = 'household-456';
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        primary_household_id: householdId,
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      await userService.setPrimaryHousehold(userId, householdId);

      // Assert
      expect(mockUserRepository.updateUser).toHaveBeenCalledTimes(1);
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(userId, {
        primary_household_id: householdId,
      });
    });

    it('should handle null household ID', async () => {
      // Arrange
      const userId = 'test-user-id';
      const householdId = null as any; // Testing edge case
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        primary_household_id: null,
      });

      mockUserRepository.updateUser.mockResolvedValue(updatedUser);

      // Act
      const result = await userService.setPrimaryHousehold(userId, householdId);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockUserRepository.updateUser).toHaveBeenCalledWith(userId, {
        primary_household_id: null,
      });
    });
  });
});
