import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import {
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import {
  HouseholdResolver,
  Household,
  HouseholdMember,
  CreateHouseholdInput,
  GetHouseholdInput,
  AddHouseholdMemberInput,
  RemoveHouseholdMemberInput,
  ChangeHouseholdMemberRoleInput,
} from '../household.resolver.js';
import { TOKENS } from '../../../../common/tokens.js';
import { DatabaseFixtures } from '../../../../test/fixtures/database-fixtures.js';
import type {
  HouseholdRecord,
  HouseholdMemberRecord,
} from '../../household.types.js';
import type { Selectable } from 'kysely';
import type {
  Household as HouseholdDB,
  HouseholdMember as HouseholdMemberDB,
} from '../../../../generated/database.js';

// Create household test fixtures since they don't exist in DatabaseFixtures yet
const createHouseholdFixture = (
  overrides: Partial<Selectable<HouseholdDB>> = {},
): HouseholdRecord => ({
  id: 'test-household-id',
  name: 'Test Household',
  description: 'A test household',
  created_by: 'test-user-id',
  created_at: new Date('2023-01-01'),
  updated_at: new Date('2023-01-01'),
  ...overrides,
});

const createHouseholdMemberFixture = (
  overrides: Partial<Selectable<HouseholdMemberDB>> = {},
): HouseholdMemberRecord => ({
  id: 'test-member-id',
  household_id: 'test-household-id',
  user_id: 'test-user-id',
  role: 'member',
  joined_at: new Date('2023-01-01'),
  ...overrides,
});

describe('HouseholdResolver', () => {
  let householdResolver: HouseholdResolver;
  let mockGuardedHouseholdService: {
    createHousehold: ReturnType<typeof vi.fn>;
    getHousehold: ReturnType<typeof vi.fn>;
    addHouseholdMember: ReturnType<typeof vi.fn>;
    removeHouseholdMember: ReturnType<typeof vi.fn>;
    changeHouseholdMemberRole: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    // Create mocks
    mockGuardedHouseholdService = {
      createHousehold: vi.fn(),
      getHousehold: vi.fn(),
      addHouseholdMember: vi.fn(),
      removeHouseholdMember: vi.fn(),
      changeHouseholdMemberRole: vi.fn(),
    };

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        HouseholdResolver,
        {
          provide: TOKENS.HOUSEHOLD.GUARDED_SERVICE,
          useValue: mockGuardedHouseholdService,
        },
      ],
    }).compile();

    householdResolver = module.get<HouseholdResolver>(HouseholdResolver);
  });

  describe('createHousehold', () => {
    it('should create household successfully', async () => {
      // Arrange
      const input: CreateHouseholdInput = {
        name: 'New Household',
        description: 'A new household for testing',
      };
      const user = DatabaseFixtures.createUserResult({
        id: 'creator-user-id',
      });
      const createdHousehold = createHouseholdFixture({
        id: 'new-household-id',
        name: 'New Household',
        description: 'A new household for testing',
        created_by: 'creator-user-id',
      });

      mockGuardedHouseholdService.createHousehold.mockResolvedValue({
        household: createdHousehold,
      });

      // Act
      const result = await householdResolver.createHousehold(input, user);

      // Assert
      expect(result).toEqual({
        id: createdHousehold.id,
        name: createdHousehold.name,
        description: createdHousehold.description,
        created_by: createdHousehold.created_by,
        created_at: createdHousehold.created_at,
        updated_at: createdHousehold.updated_at,
      } satisfies Household);
      expect(mockGuardedHouseholdService.createHousehold).toHaveBeenCalledWith(
        input,
        user,
      );
    });

    it('should create household without description', async () => {
      // Arrange
      const input: CreateHouseholdInput = {
        name: 'Minimal Household',
      };
      const user = DatabaseFixtures.createUserResult();
      const createdHousehold = createHouseholdFixture({
        name: 'Minimal Household',
        description: null,
      });

      mockGuardedHouseholdService.createHousehold.mockResolvedValue({
        household: createdHousehold,
      });

      // Act
      const result = await householdResolver.createHousehold(input, user);

      // Assert
      expect(result.name).toBe('Minimal Household');
      expect(result.description).toBeNull();
      expect(mockGuardedHouseholdService.createHousehold).toHaveBeenCalledWith(
        input,
        user,
      );
    });

    it('should handle UnauthorizedException', async () => {
      // Arrange
      const input: CreateHouseholdInput = { name: 'Test Household' };
      const user = null;

      mockGuardedHouseholdService.createHousehold.mockRejectedValue(
        new UnauthorizedException('User not found'),
      );

      // Act & Assert
      await expect(
        householdResolver.createHousehold(input, user),
      ).rejects.toThrow(UnauthorizedException);
      expect(mockGuardedHouseholdService.createHousehold).toHaveBeenCalledWith(
        input,
        user,
      );
    });

    it('should handle BadRequestException for invalid name', async () => {
      // Arrange
      const input: CreateHouseholdInput = { name: '' };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.createHousehold.mockRejectedValue(
        new BadRequestException('Household name is required'),
      );

      // Act & Assert
      await expect(
        householdResolver.createHousehold(input, user),
      ).rejects.toThrow(BadRequestException);
      expect(mockGuardedHouseholdService.createHousehold).toHaveBeenCalledWith(
        input,
        user,
      );
    });

    it('should handle ForbiddenException for insufficient permissions', async () => {
      // Arrange
      const input: CreateHouseholdInput = { name: 'Test Household' };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.createHousehold.mockRejectedValue(
        new ForbiddenException('Insufficient permissions to create household'),
      );

      // Act & Assert
      await expect(
        householdResolver.createHousehold(input, user),
      ).rejects.toThrow(ForbiddenException);
      expect(mockGuardedHouseholdService.createHousehold).toHaveBeenCalledWith(
        input,
        user,
      );
    });
  });

  describe('household', () => {
    it('should get household successfully', async () => {
      // Arrange
      const input: GetHouseholdInput = { id: 'test-household-id' };
      const user = DatabaseFixtures.createUserResult();
      const household = createHouseholdFixture({
        id: 'test-household-id',
        name: 'Retrieved Household',
      });

      mockGuardedHouseholdService.getHousehold.mockResolvedValue({
        household,
      });

      // Act
      const result = await householdResolver.household(input, user);

      // Assert
      expect(result).toEqual({
        id: household.id,
        name: household.name,
        description: household.description,
        created_by: household.created_by,
        created_at: household.created_at,
        updated_at: household.updated_at,
      } satisfies Household);
      expect(mockGuardedHouseholdService.getHousehold).toHaveBeenCalledWith(
        'test-household-id',
        user,
      );
    });

    it('should handle UnauthorizedException', async () => {
      // Arrange
      const input: GetHouseholdInput = { id: 'test-household-id' };
      const user = null;

      mockGuardedHouseholdService.getHousehold.mockRejectedValue(
        new UnauthorizedException('User not found'),
      );

      // Act & Assert
      await expect(householdResolver.household(input, user)).rejects.toThrow(
        UnauthorizedException,
      );
      expect(mockGuardedHouseholdService.getHousehold).toHaveBeenCalledWith(
        'test-household-id',
        user,
      );
    });

    it('should handle ForbiddenException for access restrictions', async () => {
      // Arrange
      const input: GetHouseholdInput = { id: 'restricted-household-id' };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.getHousehold.mockRejectedValue(
        new ForbiddenException(
          'Insufficient permissions to read this household',
        ),
      );

      // Act & Assert
      await expect(householdResolver.household(input, user)).rejects.toThrow(
        ForbiddenException,
      );
      expect(mockGuardedHouseholdService.getHousehold).toHaveBeenCalledWith(
        'restricted-household-id',
        user,
      );
    });

    it('should handle BadRequestException for invalid input', async () => {
      // Arrange
      const input: GetHouseholdInput = { id: '' };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.getHousehold.mockRejectedValue(
        new BadRequestException('Household ID is required'),
      );

      // Act & Assert
      await expect(householdResolver.household(input, user)).rejects.toThrow(
        BadRequestException,
      );
      expect(mockGuardedHouseholdService.getHousehold).toHaveBeenCalledWith(
        '',
        user,
      );
    });
  });

  describe('addHouseholdMember', () => {
    it('should add household member successfully', async () => {
      // Arrange
      const input: AddHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'new-user-id',
        role: 'member',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'manager-user-id' });
      const newMember = createHouseholdMemberFixture({
        household_id: 'test-household-id',
        user_id: 'new-user-id',
        role: 'member',
      });

      mockGuardedHouseholdService.addHouseholdMember.mockResolvedValue(
        newMember,
      );

      // Act
      const result = await householdResolver.addHouseholdMember(input, user);

      // Assert
      expect(result).toEqual({
        id: newMember.id,
        household_id: newMember.household_id,
        user_id: newMember.user_id,
        role: newMember.role,
        joined_at: newMember.joined_at,
      } satisfies HouseholdMember);
      expect(
        mockGuardedHouseholdService.addHouseholdMember,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'new-user-id', role: 'member' },
        user,
      );
    });

    it('should handle manager role assignment', async () => {
      // Arrange
      const input: AddHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'new-manager-id',
        role: 'manager',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'owner-user-id' });
      const newManager = createHouseholdMemberFixture({
        user_id: 'new-manager-id',
        role: 'manager',
      });

      mockGuardedHouseholdService.addHouseholdMember.mockResolvedValue(
        newManager,
      );

      // Act
      const result = await householdResolver.addHouseholdMember(input, user);

      // Assert
      expect(result.role).toBe('manager');
      expect(
        mockGuardedHouseholdService.addHouseholdMember,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'new-manager-id', role: 'manager' },
        user,
      );
    });

    it('should handle ForbiddenException for non-managers', async () => {
      // Arrange
      const input: AddHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'new-user-id',
        role: 'member',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'regular-user-id' });

      mockGuardedHouseholdService.addHouseholdMember.mockRejectedValue(
        new ForbiddenException('Only household managers can add members'),
      );

      // Act & Assert
      await expect(
        householdResolver.addHouseholdMember(input, user),
      ).rejects.toThrow(ForbiddenException);
      expect(
        mockGuardedHouseholdService.addHouseholdMember,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'new-user-id', role: 'member' },
        user,
      );
    });

    it('should handle validation errors', async () => {
      // Arrange
      const input: AddHouseholdMemberInput = {
        householdId: '',
        userId: 'new-user-id',
        role: 'member',
      };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.addHouseholdMember.mockRejectedValue(
        new BadRequestException('Household ID is required'),
      );

      // Act & Assert
      await expect(
        householdResolver.addHouseholdMember(input, user),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('removeHouseholdMember', () => {
    it('should remove household member successfully', async () => {
      // Arrange
      const input: RemoveHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'user-to-remove-id',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'manager-user-id' });

      mockGuardedHouseholdService.removeHouseholdMember.mockResolvedValue(
        undefined,
      );

      // Act
      const result = await householdResolver.removeHouseholdMember(input, user);

      // Assert
      expect(result).toBe(true);
      expect(
        mockGuardedHouseholdService.removeHouseholdMember,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'user-to-remove-id' },
        user,
      );
    });

    it('should handle ForbiddenException for non-managers', async () => {
      // Arrange
      const input: RemoveHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'user-to-remove-id',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'regular-user-id' });

      mockGuardedHouseholdService.removeHouseholdMember.mockRejectedValue(
        new ForbiddenException('Only household managers can remove members'),
      );

      // Act & Assert
      await expect(
        householdResolver.removeHouseholdMember(input, user),
      ).rejects.toThrow(ForbiddenException);
      expect(
        mockGuardedHouseholdService.removeHouseholdMember,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'user-to-remove-id' },
        user,
      );
    });

    it('should handle validation errors', async () => {
      // Arrange
      const input: RemoveHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: '',
      };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.removeHouseholdMember.mockRejectedValue(
        new BadRequestException('User ID is required'),
      );

      // Act & Assert
      await expect(
        householdResolver.removeHouseholdMember(input, user),
      ).rejects.toThrow(BadRequestException);
    });

    it('should handle UnauthorizedException', async () => {
      // Arrange
      const input: RemoveHouseholdMemberInput = {
        householdId: 'test-household-id',
        userId: 'user-to-remove-id',
      };
      const user = null;

      mockGuardedHouseholdService.removeHouseholdMember.mockRejectedValue(
        new UnauthorizedException('User not found'),
      );

      // Act & Assert
      await expect(
        householdResolver.removeHouseholdMember(input, user),
      ).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('changeHouseholdMemberRole', () => {
    it('should change household member role successfully', async () => {
      // Arrange
      const input: ChangeHouseholdMemberRoleInput = {
        householdId: 'test-household-id',
        userId: 'member-user-id',
        newRole: 'manager',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'owner-user-id' });
      const updatedMember = createHouseholdMemberFixture({
        user_id: 'member-user-id',
        role: 'manager',
      });

      mockGuardedHouseholdService.changeHouseholdMemberRole.mockResolvedValue(
        updatedMember,
      );

      // Act
      const result = await householdResolver.changeHouseholdMemberRole(
        input,
        user,
      );

      // Assert
      expect(result).toEqual({
        id: updatedMember.id,
        household_id: updatedMember.household_id,
        user_id: updatedMember.user_id,
        role: updatedMember.role,
        joined_at: updatedMember.joined_at,
      } satisfies HouseholdMember);
      expect(
        mockGuardedHouseholdService.changeHouseholdMemberRole,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'member-user-id', newRole: 'manager' },
        user,
      );
    });

    it('should demote manager to member', async () => {
      // Arrange
      const input: ChangeHouseholdMemberRoleInput = {
        householdId: 'test-household-id',
        userId: 'manager-user-id',
        newRole: 'member',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'owner-user-id' });
      const demotedMember = createHouseholdMemberFixture({
        user_id: 'manager-user-id',
        role: 'member',
      });

      mockGuardedHouseholdService.changeHouseholdMemberRole.mockResolvedValue(
        demotedMember,
      );

      // Act
      const result = await householdResolver.changeHouseholdMemberRole(
        input,
        user,
      );

      // Assert
      expect(result.role).toBe('member');
      expect(
        mockGuardedHouseholdService.changeHouseholdMemberRole,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'manager-user-id', newRole: 'member' },
        user,
      );
    });

    it('should handle ForbiddenException for non-managers', async () => {
      // Arrange
      const input: ChangeHouseholdMemberRoleInput = {
        householdId: 'test-household-id',
        userId: 'other-user-id',
        newRole: 'manager',
      };
      const user = DatabaseFixtures.createUserResult({ id: 'regular-user-id' });

      mockGuardedHouseholdService.changeHouseholdMemberRole.mockRejectedValue(
        new ForbiddenException(
          'Only household managers can change member roles',
        ),
      );

      // Act & Assert
      await expect(
        householdResolver.changeHouseholdMemberRole(input, user),
      ).rejects.toThrow(ForbiddenException);
      expect(
        mockGuardedHouseholdService.changeHouseholdMemberRole,
      ).toHaveBeenCalledWith(
        'test-household-id',
        { userId: 'other-user-id', newRole: 'manager' },
        user,
      );
    });

    it('should handle validation errors for empty role', async () => {
      // Arrange
      const input: ChangeHouseholdMemberRoleInput = {
        householdId: 'test-household-id',
        userId: 'member-user-id',
        newRole: '',
      };
      const user = DatabaseFixtures.createUserResult();

      mockGuardedHouseholdService.changeHouseholdMemberRole.mockRejectedValue(
        new BadRequestException('New role is required'),
      );

      // Act & Assert
      await expect(
        householdResolver.changeHouseholdMemberRole(input, user),
      ).rejects.toThrow(BadRequestException);
    });

    it('should handle service errors gracefully', async () => {
      // Arrange
      const input: ChangeHouseholdMemberRoleInput = {
        householdId: 'test-household-id',
        userId: 'member-user-id',
        newRole: 'manager',
      };
      const user = DatabaseFixtures.createUserResult();
      const serviceError = new Error('Database constraint violation');

      mockGuardedHouseholdService.changeHouseholdMemberRole.mockRejectedValue(
        serviceError,
      );

      // Act & Assert
      await expect(
        householdResolver.changeHouseholdMemberRole(input, user),
      ).rejects.toThrow(serviceError);
    });
  });
});
