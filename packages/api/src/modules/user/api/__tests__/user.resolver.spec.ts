import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { UnauthorizedException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { UserResolver, User, GetUserInput } from '../user.resolver.js';
import { GuardedUserService } from '../guarded-user.service.js';
import { TOKENS } from '../../../../common/tokens.js';
import { DatabaseFixtures } from '../../../../test/fixtures/database-fixtures.js';
import type { UserRecord } from '../../user.types.js';

describe('UserResolver', () => {
  let userResolver: UserResolver;
  let mockGuardedUserService: {
    getUser: ReturnType<typeof vi.fn>;
    getCurrentUser: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    // Create mocks
    mockGuardedUserService = {
      getUser: vi.fn(),
      getCurrentUser: vi.fn(),
    };

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
});