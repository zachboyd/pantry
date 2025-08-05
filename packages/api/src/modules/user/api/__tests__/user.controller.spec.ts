import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import {
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { UserController } from '../user.controller.js';
import { TOKENS } from '../../../../common/tokens.js';
import { DatabaseFixtures } from '../../../../test/fixtures/database-fixtures.js';
import { GuardedUserServiceMock } from '../../../../test/mocks/guarded-user-service.mock.js';
import type { GuardedUserServiceMockType } from '../../../../test/mocks/guarded-user-service.mock.js';
import type { UpdateUserInput } from '../guarded-user.service.js';

describe('UserController', () => {
  let controller: UserController;
  let mockGuardedUserService: GuardedUserServiceMockType;

  beforeEach(async () => {
    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

    // Create reusable mock
    mockGuardedUserService =
      GuardedUserServiceMock.createGuardedUserServiceMock();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [UserController],
      providers: [
        {
          provide: TOKENS.USER.GUARDED_SERVICE,
          useValue: mockGuardedUserService,
        },
      ],
    }).compile();

    controller = module.get<UserController>(UserController);
  });

  describe('getCurrentUser', () => {
    it('should return current user when authenticated', async () => {
      // Arrange
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Current',
        last_name: 'User',
      });

      mockGuardedUserService.getCurrentUser.mockResolvedValue({
        user: currentUser,
      });

      // Act
      const result = await controller.getCurrentUser(currentUser);

      // Assert
      expect(result).toEqual(currentUser);
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        currentUser,
      );
    });

    it('should handle UnauthorizedException when user not authenticated', async () => {
      // Arrange
      mockGuardedUserService.getCurrentUser.mockRejectedValue(
        new UnauthorizedException('User must be authenticated'),
      );

      // Act & Assert
      await expect(controller.getCurrentUser(null)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(null);
    });
  });

  describe('getUser', () => {
    it('should return user when found and accessible', async () => {
      // Arrange
      const userId = 'test-user-id';
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const targetUser = DatabaseFixtures.createUserResult({
        id: userId,
        first_name: 'Target',
        last_name: 'User',
      });

      mockGuardedUserService.getUser.mockResolvedValue({
        user: targetUser,
      });

      // Act
      const result = await controller.getUser(userId, currentUser);

      // Assert
      expect(result).toEqual(targetUser);
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        userId,
        currentUser,
      );
    });

    it('should handle NotFoundException when user not found', async () => {
      // Arrange
      const userId = 'nonexistent-user-id';
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.getUser.mockRejectedValue(
        new NotFoundException('User with ID nonexistent-user-id not found'),
      );

      // Act & Assert
      await expect(controller.getUser(userId, currentUser)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        userId,
        currentUser,
      );
    });
  });

  describe('updateUser', () => {
    it('should update user successfully', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData = {
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display Name',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display Name',
      });

      const expectedInput: UpdateUserInput = { id: userId, ...updateData };

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await controller.updateUser(
        userId,
        updateData,
        currentUser,
      );

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        expectedInput,
        currentUser,
      );
    });

    it('should handle UnauthorizedException when user not authenticated', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData = {
        first_name: 'Updated',
      };

      mockGuardedUserService.updateUser.mockRejectedValue(
        new UnauthorizedException('User must be authenticated'),
      );

      // Act & Assert
      await expect(
        controller.updateUser(userId, updateData, null),
      ).rejects.toThrow(UnauthorizedException);
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        { id: userId, ...updateData },
        null,
      );
    });

    it('should handle NotFoundException when user not found', async () => {
      // Arrange
      const userId = 'nonexistent-user-id';
      const updateData = {
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.updateUser.mockRejectedValue(
        new NotFoundException('User with ID nonexistent-user-id not found'),
      );

      // Act & Assert
      await expect(
        controller.updateUser(userId, updateData, currentUser),
      ).rejects.toThrow(NotFoundException);
    });

    it('should handle ForbiddenException when user lacks permission', async () => {
      // Arrange
      const userId = 'other-user-id';
      const updateData = {
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.updateUser.mockRejectedValue(
        new ForbiddenException(
          'You do not have permission to update this user',
        ),
      );

      // Act & Assert
      await expect(
        controller.updateUser(userId, updateData, currentUser),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should update user with partial data', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData = {
        first_name: 'OnlyFirstName',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        first_name: 'OnlyFirstName',
        last_name: 'OriginalLast', // unchanged
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await controller.updateUser(
        userId,
        updateData,
        currentUser,
      );

      // Assert
      expect(result.first_name).toBe('OnlyFirstName');
      expect(result.last_name).toBe('OriginalLast');
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        { id: userId, ...updateData },
        currentUser,
      );
    });

    it('should update own profile successfully', async () => {
      // Arrange
      const userId = 'current-user-id';
      const updateData = {
        display_name: 'My New Display Name',
        phone: '+1234567890',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        display_name: 'My New Display Name',
        phone: '+1234567890',
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await controller.updateUser(
        userId,
        updateData,
        currentUser,
      );

      // Assert
      expect(result.display_name).toBe('My New Display Name');
      expect(result.phone).toBe('+1234567890');
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        { id: userId, ...updateData },
        currentUser,
      );
    });

    it('should handle all supported update fields', async () => {
      // Arrange
      const userId = 'test-user-id';
      const updateData = {
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Updated Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        birth_date: new Date('1990-01-01'),
        email: 'updated@example.com',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: userId,
        ...updateData,
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await controller.updateUser(
        userId,
        updateData,
        currentUser,
      );

      // Assert
      expect(result).toMatchObject(updateData);
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        { id: userId, ...updateData },
        currentUser,
      );
    });
  });
});
