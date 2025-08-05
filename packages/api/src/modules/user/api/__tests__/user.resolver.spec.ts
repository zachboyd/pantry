import { describe, it, expect, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import {
  UnauthorizedException,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { UserResolver, GetUserInput, UpdateUserInput } from '../user.resolver.js';
import { TOKENS } from '../../../../common/tokens.js';
import { DatabaseFixtures } from '../../../../test/fixtures/database-fixtures.js';
import { GuardedUserServiceMock } from '../../../../test/mocks/guarded-user-service.mock.js';
import type { GuardedUserServiceMockType } from '../../../../test/mocks/guarded-user-service.mock.js';

describe('UserResolver', () => {
  let userResolver: UserResolver;
  let mockGuardedUserService: GuardedUserServiceMockType;

  beforeEach(async () => {
    // Create reusable mock
    mockGuardedUserService = GuardedUserServiceMock.createGuardedUserServiceMock();

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        UserResolver,
        {
          provide: TOKENS.USER.GUARDED_SERVICE,
          useValue: mockGuardedUserService,
        },
      ],
    }).compile();

    userResolver = module.get<UserResolver>(UserResolver);
  });

  describe('user', () => {
    it('should return user when found', async () => {
      // Arrange
      const input: GetUserInput = { id: 'test-user-id' };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const targetUser = DatabaseFixtures.createUserResult({
        id: 'test-user-id',
        first_name: 'Target',
        last_name: 'User',
      });

      mockGuardedUserService.getUser.mockResolvedValue({ user: targetUser });

      // Act
      const result = await userResolver.user(input, currentUser);

      // Assert
      expect(result).toMatchObject({
        id: targetUser.id,
        auth_user_id: targetUser.auth_user_id,
        email: targetUser.email,
        first_name: targetUser.first_name,
        last_name: targetUser.last_name,
        display_name: targetUser.display_name,
        avatar_url: targetUser.avatar_url,
        phone: targetUser.phone,
        birth_date: targetUser.birth_date,
        managed_by: targetUser.managed_by,
        relationship_to_manager: targetUser.relationship_to_manager,
        primary_household_id: targetUser.primary_household_id,
        created_at: targetUser.created_at,
        updated_at: targetUser.updated_at,
      });
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        'test-user-id',
        currentUser,
      );
    });

    it('should handle UnauthorizedException', async () => {
      // Arrange
      const input: GetUserInput = { id: 'test-user-id' };
      const currentUser = null;

      mockGuardedUserService.getUser.mockRejectedValue(
        new UnauthorizedException('User must be authenticated'),
      );

      // Act & Assert
      await expect(userResolver.user(input, currentUser)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        'test-user-id',
        currentUser,
      );
    });

    it('should handle ForbiddenException', async () => {
      // Arrange
      const input: GetUserInput = { id: 'other-user-id' };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.getUser.mockRejectedValue(
        new ForbiddenException('You do not have permission to view this user'),
      );

      // Act & Assert
      await expect(userResolver.user(input, currentUser)).rejects.toThrow(
        ForbiddenException,
      );
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        'other-user-id',
        currentUser,
      );
    });

    it('should handle NotFoundException', async () => {
      // Arrange
      const input: GetUserInput = { id: 'nonexistent-user-id' };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.getUser.mockRejectedValue(
        new NotFoundException('User with ID nonexistent-user-id not found'),
      );

      // Act & Assert
      await expect(userResolver.user(input, currentUser)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        'nonexistent-user-id',
        currentUser,
      );
    });

    it('should handle input with special characters', async () => {
      // Arrange
      const input: GetUserInput = { id: 'user-with-special-chars-123' };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const targetUser = DatabaseFixtures.createUserResult({
        id: 'user-with-special-chars-123',
      });

      mockGuardedUserService.getUser.mockResolvedValue({ user: targetUser });

      // Act
      const result = await userResolver.user(input, currentUser);

      // Assert
      expect(result.id).toBe('user-with-special-chars-123');
      expect(mockGuardedUserService.getUser).toHaveBeenCalledWith(
        'user-with-special-chars-123',
        currentUser,
      );
    });
  });

  describe('currentUser', () => {
    it('should return current user when authenticated', async () => {
      // Arrange
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Current',
        last_name: 'User',
        email: 'current@example.com',
      });

      mockGuardedUserService.getCurrentUser.mockResolvedValue({
        user: currentUser,
      });

      // Act
      const result = await userResolver.currentUser(currentUser);

      // Assert
      expect(result).toMatchObject({
        id: currentUser.id,
        auth_user_id: currentUser.auth_user_id,
        email: currentUser.email,
        first_name: currentUser.first_name,
        last_name: currentUser.last_name,
        display_name: currentUser.display_name,
        avatar_url: currentUser.avatar_url,
        phone: currentUser.phone,
        birth_date: currentUser.birth_date,
        managed_by: currentUser.managed_by,
        relationship_to_manager: currentUser.relationship_to_manager,
        primary_household_id: currentUser.primary_household_id,
        created_at: currentUser.created_at,
        updated_at: currentUser.updated_at,
      });
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        currentUser,
      );
    });

    it('should handle UnauthorizedException when not authenticated', async () => {
      // Arrange
      const currentUser = null;

      mockGuardedUserService.getCurrentUser.mockRejectedValue(
        new UnauthorizedException('User must be authenticated'),
      );

      // Act & Assert
      await expect(userResolver.currentUser(currentUser)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        currentUser,
      );
    });

    it('should handle NotFoundException when current user not found in database', async () => {
      // Arrange
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'orphaned-user-id',
      });

      mockGuardedUserService.getCurrentUser.mockRejectedValue(
        new NotFoundException('Current user not found'),
      );

      // Act & Assert
      await expect(userResolver.currentUser(currentUser)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        currentUser,
      );
    });

    it('should return refreshed user data from database', async () => {
      // Arrange
      const staleCurrentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Stale',
        updated_at: new Date('2023-01-01'),
      });

      const freshCurrentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        first_name: 'Fresh',
        updated_at: new Date('2023-12-01'),
      });

      mockGuardedUserService.getCurrentUser.mockResolvedValue({
        user: freshCurrentUser,
      });

      // Act
      const result = await userResolver.currentUser(staleCurrentUser);

      // Assert
      expect(result.first_name).toBe('Fresh');
      expect(result.updated_at).toEqual(new Date('2023-12-01'));
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        staleCurrentUser,
      );
    });

    it('should handle service errors gracefully', async () => {
      // Arrange
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const serviceError = new Error('Database connection failed');

      mockGuardedUserService.getCurrentUser.mockRejectedValue(serviceError);

      // Act & Assert
      await expect(userResolver.currentUser(currentUser)).rejects.toThrow(
        serviceError,
      );
      expect(mockGuardedUserService.getCurrentUser).toHaveBeenCalledWith(
        currentUser,
      );
    });
  });

  describe('updateUser', () => {
    it('should update user when service succeeds', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'test-user-id',
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display Name',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'test-user-id',
        first_name: 'Updated',
        last_name: 'Name',
        display_name: 'Updated Display Name',
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should handle UnauthorizedException when user not authenticated', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'test-user-id',
        first_name: 'Updated',
      };

      mockGuardedUserService.updateUser.mockRejectedValue(
        new UnauthorizedException('User must be authenticated'),
      );

      // Act & Assert
      await expect(userResolver.updateUser(input, null)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        null,
      );
    });

    it('should handle NotFoundException when user not found', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'nonexistent-user-id',
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.updateUser.mockRejectedValue(
        new NotFoundException('User with ID nonexistent-user-id not found'),
      );

      // Act & Assert
      await expect(userResolver.updateUser(input, currentUser)).rejects.toThrow(
        NotFoundException,
      );
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should handle ForbiddenException when user lacks permission', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'other-user-id',
        first_name: 'Updated',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });

      mockGuardedUserService.updateUser.mockRejectedValue(
        new ForbiddenException('You do not have permission to update this user'),
      );

      // Act & Assert
      await expect(userResolver.updateUser(input, currentUser)).rejects.toThrow(
        ForbiddenException,
      );
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should update user with partial data', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'test-user-id',
        first_name: 'OnlyFirstName',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'test-user-id',
        first_name: 'OnlyFirstName',
        last_name: 'OriginalLast', // unchanged
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result.first_name).toBe('OnlyFirstName');
      expect(result.last_name).toBe('OriginalLast');
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should update own profile successfully', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'current-user-id',
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
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result.display_name).toBe('My New Display Name');
      expect(result.phone).toBe('+1234567890');
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should update primary_household_id successfully', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'current-user-id',
        primary_household_id: 'new-household-id',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        primary_household_id: 'old-household-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        primary_household_id: 'new-household-id',
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result.primary_household_id).toBe('new-household-id');
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should set primary_household_id to null', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'current-user-id',
        primary_household_id: null,
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        primary_household_id: 'old-household-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        primary_household_id: null,
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result.primary_household_id).toBe(null);
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });

    it('should update primary_household_id along with other fields', async () => {
      // Arrange
      const input: UpdateUserInput = {
        id: 'current-user-id',
        primary_household_id: 'new-household-id',
        first_name: 'Updated',
        display_name: 'Updated Display',
      };
      const currentUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
      });
      const updatedUser = DatabaseFixtures.createUserResult({
        id: 'current-user-id',
        primary_household_id: 'new-household-id',
        first_name: 'Updated',
        display_name: 'Updated Display',
      });

      mockGuardedUserService.updateUser.mockResolvedValue({
        user: updatedUser,
      });

      // Act
      const result = await userResolver.updateUser(input, currentUser);

      // Assert
      expect(result).toMatchObject({
        id: 'current-user-id',
        primary_household_id: 'new-household-id',
        first_name: 'Updated',
        display_name: 'Updated Display',
      });
      expect(mockGuardedUserService.updateUser).toHaveBeenCalledWith(
        input,
        currentUser,
      );
    });
  });
});
