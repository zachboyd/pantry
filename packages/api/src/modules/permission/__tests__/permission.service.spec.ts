import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { AbilityBuilder, PureAbility, subject } from '@casl/ability';
import { packRules } from '@casl/ability/extra';
import { PermissionServiceImpl } from '../permission.service.js';
import { TOKENS } from '../../../common/tokens.js';
import { HouseholdRole } from '../../../common/enums.js';
import { AppAbility } from '../permission.types.js';
import { DatabaseMock } from '../../../test/utils/database-mock.js';
import { CacheManagerMock } from '../../../test/mocks/cache-manager.mock.js';
import { CacheHelperMock } from '../../../test/mocks/cache-helper.mock.js';
import { PermissionFixtures } from '../../../test/fixtures/permission-fixtures.js';
import type { KyselyMock } from '../../../test/utils/database-mock.js';
import type { CacheManagerMockType } from '../../../test/mocks/cache-manager.mock.js';
import type { CacheHelperMockType } from '../../../test/mocks/cache-helper.mock.js';

describe('PermissionService', () => {
  let service: PermissionServiceImpl;
  let mockDb: KyselyMock;
  let mockCache: CacheManagerMockType;
  let mockCacheHelper: CacheHelperMockType;

  beforeEach(async () => {
    // Create reusable mocks
    mockDb = DatabaseMock.createKyselyMock();
    mockCache = CacheManagerMock.createCacheManagerMock();
    mockCacheHelper = CacheHelperMock.createCacheHelperMock();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PermissionServiceImpl,
        {
          provide: TOKENS.DATABASE.CONNECTION,
          useValue: mockDb,
        },
        {
          provide: TOKENS.CACHE.MANAGER,
          useValue: mockCache,
        },
        {
          provide: TOKENS.CACHE.HELPER,
          useValue: mockCacheHelper,
        },
      ],
    }).compile();

    service = module.get<PermissionServiceImpl>(PermissionServiceImpl);
  });

  describe('computeUserPermissions', () => {
    it('should compute permissions for user with manager role', async () => {
      const userId = 'test-manager-user';
      const householdId = 'test-household-id';

      // Use fixture for household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MANAGER,
        householdId
      );

      // Setup database mock to return manager household membership
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined); // For update operation

      const ability = await service.computeUserPermissions(userId);

      // Test manager permissions
      expect(ability.can('manage', 'Household')).toBe(true);
      expect(ability.can('read', 'User')).toBe(true);
      expect(ability.can('manage', 'Message')).toBe(true);
      expect(ability.can('manage', 'HouseholdMember')).toBe(true);

      // Verify database calls
      expect(mockDb.selectFrom).toHaveBeenCalledWith('household_member');
      expect(mockDb.updateTable).toHaveBeenCalledWith('user');
    });

    it('should compute permissions for user with member role', async () => {
      const userId = 'test-member-user';
      const householdId = 'test-household-id';

      // Use fixture for household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MEMBER,
        householdId
      );

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Test member permissions
      expect(ability.can('read', 'Household')).toBe(true);
      expect(ability.can('manage', 'Household')).toBe(false);
      expect(ability.can('create', 'Message')).toBe(true);
      expect(ability.can('read', 'Message')).toBe(true);
      expect(ability.can('read', 'HouseholdMember')).toBe(true);
    });

    it('should compute permissions for user with AI role', async () => {
      const userId = 'test-ai-user';
      const householdId = 'test-household-id';

      // Use fixture for AI household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.AI,
        householdId
      );

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Test AI permissions
      expect(ability.can('read', 'Household')).toBe(true);
      expect(ability.can('create', 'Message')).toBe(true);
      expect(ability.can('read', 'Message')).toBe(true);
      expect(ability.can('update', 'User')).toBe(false);
      expect(ability.can('create', 'HouseholdMember')).toBe(false);
    });

    it('should handle user with multiple household roles', async () => {
      const userId = 'test-multi-household-user';

      // Use fixture for multiple household member records
      const householdMembers = PermissionFixtures.createMultipleHouseholdMemberRecords(userId);

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should have manager permissions (highest level)
      expect(ability.can('manage', 'Household')).toBe(true);
      expect(ability.can('manage', 'Message')).toBe(true);
    });

    it('should handle user with no household roles', async () => {
      const userId = 'test-no-household-user';

      // Setup database mock to return empty array (no household memberships)
      mockDb.mockBuilder.mockExecute([]);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should only have base permissions (own profile)
      expect(ability.can('read', 'User')).toBe(true);
      expect(ability.can('read', 'Household')).toBe(false);
      expect(ability.can('create', 'Message')).toBe(false);
    });

    it('should prevent cross-household access - Manager in Household A cannot access Household B', async () => {
      const userId = 'test-manager-user';
      const ownHouseholdId = 'household-a';
      const otherHouseholdId = 'household-b';

      // User is manager of household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MANAGER,
        ownHouseholdId
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should be able to access own household
      expect(ability.can('read', subject('Household', { id: ownHouseholdId }))).toBe(true);
      expect(ability.can('manage', subject('Household', { id: ownHouseholdId }))).toBe(true);
      expect(ability.can('read', subject('Message', { household_id: ownHouseholdId }))).toBe(true);
      expect(ability.can('manage', subject('Message', { household_id: ownHouseholdId }))).toBe(true);

      // Should NOT be able to access other household
      expect(ability.can('read', subject('Household', { id: otherHouseholdId }))).toBe(false);
      expect(ability.can('manage', subject('Household', { id: otherHouseholdId }))).toBe(false);
      expect(ability.can('read', subject('Message', { household_id: otherHouseholdId }))).toBe(false);
      expect(ability.can('manage', subject('Message', { household_id: otherHouseholdId }))).toBe(false);
    });

    it('should prevent cross-household access - Member in Household A cannot access Household B', async () => {
      const userId = 'test-member-user';
      const ownHouseholdId = 'household-a';
      const otherHouseholdId = 'household-b';

      // User is member of household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MEMBER,
        ownHouseholdId
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should be able to access own household (read-only)
      expect(ability.can('read', subject('Household', { id: ownHouseholdId }))).toBe(true);
      expect(ability.can('read', subject('Message', { household_id: ownHouseholdId }))).toBe(true);
      expect(ability.can('create', subject('Message', { household_id: ownHouseholdId }))).toBe(true);

      // Should NOT be able to access other household
      expect(ability.can('read', subject('Household', { id: otherHouseholdId }))).toBe(false);
      expect(ability.can('read', subject('Message', { household_id: otherHouseholdId }))).toBe(false);
      expect(ability.can('create', subject('Message', { household_id: otherHouseholdId }))).toBe(false);
    });

    it('should prevent cross-household access - AI in Household A cannot access Household B', async () => {
      const userId = 'test-ai-user';
      const ownHouseholdId = 'household-a';
      const otherHouseholdId = 'household-b';

      // User is AI in household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.AI,
        ownHouseholdId
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should be able to access own household (read and create messages)
      expect(ability.can('read', subject('Household', { id: ownHouseholdId }))).toBe(true);
      expect(ability.can('read', subject('Message', { household_id: ownHouseholdId }))).toBe(true);
      expect(ability.can('create', subject('Message', { household_id: ownHouseholdId }))).toBe(true);

      // Should NOT be able to access other household
      expect(ability.can('read', subject('Household', { id: otherHouseholdId }))).toBe(false);
      expect(ability.can('read', subject('Message', { household_id: otherHouseholdId }))).toBe(false);
      expect(ability.can('create', subject('Message', { household_id: otherHouseholdId }))).toBe(false);

      // AI restrictions should still apply
      expect(ability.can('update', subject('User', { id: 'other-user-id' }))).toBe(false);
      expect(ability.can('create', 'HouseholdMember')).toBe(false);
    });

    it('should validate MongoDB $in conditions work correctly for multi-household users', async () => {
      const userId = 'test-multi-household-user';
      const householdA = 'household-a';
      const householdB = 'household-b';
      const householdC = 'household-c'; // Not member of this one

      // User is manager of household-a and member of household-b
      const householdMembers = [
        {
          household_id: householdA,
          role: HouseholdRole.MANAGER,
          user_id: userId,
          created_at: new Date(),
          updated_at: new Date(),
        },
        {
          household_id: householdB,
          role: HouseholdRole.MEMBER,  
          user_id: userId,
          created_at: new Date(),
          updated_at: new Date(),
        }
      ];

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should have manager access to household-a
      expect(ability.can('manage', subject('Household', { id: householdA }))).toBe(true);
      expect(ability.can('manage', subject('Message', { household_id: householdA }))).toBe(true);

      // Should have member access to household-b  
      expect(ability.can('read', subject('Household', { id: householdB }))).toBe(true);
      expect(ability.can('create', subject('Message', { household_id: householdB }))).toBe(true);
      expect(ability.can('manage', subject('Message', { household_id: householdB }))).toBe(false);

      // Should NOT have access to household-c
      expect(ability.can('read', subject('Household', { id: householdC }))).toBe(false);
      expect(ability.can('read', subject('Message', { household_id: householdC }))).toBe(false);
      expect(ability.can('create', subject('Message', { household_id: householdC }))).toBe(false);
    });

    it('should prevent User A from reading User B in different household', async () => {
      const userA = 'user-a-id';
      const userB = 'user-b-id';
      const householdA = 'household-a';
      const householdB = 'household-b';

      // User A is manager of household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userA,
        HouseholdRole.MANAGER,
        householdA
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userA);

      // Should be able to read own profile always
      expect(ability.can('read', subject('User', { id: userA }))).toBe(true);
      expect(ability.can('update', subject('User', { id: userA }))).toBe(true);

      // Note: Complex nested MongoDB queries might not work as expected in CASL tests
      // The key security test is that User B (different household) cannot be accessed
      // Household-specific user queries would be validated at the service layer

      // Should NOT be able to read User B who is in a different household
      expect(ability.can('read', subject('User', { id: userB }))).toBe(false);
      expect(ability.can('update', subject('User', { id: userB }))).toBe(false);
      
      // Should NOT be able to read users from other households
      expect(ability.can('read', subject('User', { 
        'household_members.household_id': householdB 
      }))).toBe(false);
    });

    it('should validate Pantry cross-household restrictions', async () => {
      const userId = 'test-member-user';
      const ownHouseholdId = 'household-a';
      const otherHouseholdId = 'household-b';

      // User is member of household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MEMBER,
        ownHouseholdId
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should be able to access pantries in own household
      expect(ability.can('read', subject('Pantry', { household_id: ownHouseholdId }))).toBe(true);

      // Should NOT be able to access pantries in other households
      expect(ability.can('read', subject('Pantry', { household_id: otherHouseholdId }))).toBe(false);
    });

    it('should validate HouseholdMember management permissions across households', async () => {
      const userId = 'test-manager-user';
      const ownHouseholdId = 'household-a';
      const otherHouseholdId = 'household-b';

      // User is manager of household-a only
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MANAGER,
        ownHouseholdId
      );

      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should be able to read and manage HouseholdMembers in own household
      expect(ability.can('read', subject('HouseholdMember', { household_id: ownHouseholdId }))).toBe(true);
      expect(ability.can('create', subject('HouseholdMember', { 
        household_id: ownHouseholdId,
        role: HouseholdRole.MEMBER 
      }))).toBe(true);

      // Should NOT be able to manage other managers (business rule)
      expect(ability.can('update', subject('HouseholdMember', { 
        household_id: ownHouseholdId,
        role: HouseholdRole.MANAGER 
      }))).toBe(false);

      // Should NOT be able to access HouseholdMembers in other households
      expect(ability.can('read', subject('HouseholdMember', { household_id: otherHouseholdId }))).toBe(false);
      expect(ability.can('create', subject('HouseholdMember', { household_id: otherHouseholdId }))).toBe(false);
    });
  });

  describe('getUserPermissions', () => {
    it('should return null when user has no cached permissions', async () => {
      const userId = 'test-user-no-permissions';

      // Setup database mock to return user with null permissions
      mockDb.mockBuilder.mockExecuteTakeFirst({
        id: userId,
        permissions: null,
      });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return null when user is not found', async () => {
      const userId = 'test-user-not-found';

      // Setup database mock to return undefined (user not found)
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return ability when user has valid cached permissions', async () => {
      const userId = 'test-user-id';

      // Use fixture to create a member ability and pack it
      const testAbility = PermissionFixtures.createMemberAbility();
      const packedRules = PermissionFixtures.createPackedRules(testAbility);

      // Use fixture for user permission record
      const userPermissionRecord = PermissionFixtures.createUserPermissionRecord(
        userId,
        testAbility
      );

      // Setup database mock to return the permission record
      mockDb.mockBuilder.mockExecuteTakeFirst(userPermissionRecord);

      const result = await service.getUserPermissions(userId);

      expect(result).toBeDefined();
      expect(result?.can('read', 'User')).toBe(true);
      expect(result?.can('read', 'Household')).toBe(true);
      expect(result?.can('create', 'Message')).toBe(true);
    });

    it('should return null when permissions JSON is invalid', async () => {
      const userId = 'test-user-invalid-json';

      // Setup database mock to return user with invalid JSON permissions
      mockDb.mockBuilder.mockExecuteTakeFirst({
        id: userId,
        permissions: 'invalid-json',
      });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });
  });

  describe('Cache-based permission methods', () => {
    it('should use cache.wrap for canCreateHousehold', async () => {
      const userId = 'test-user-create-household';
      const householdId = 'test-household-id';

      // Use fixture for manager household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MANAGER,
        householdId
      );

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const result = await service.canCreateHousehold(userId);

      expect(result).toBe(true);
      expect(mockCacheHelper.getCacheConfig).toHaveBeenCalledWith('permissions', `user:${userId}`);
      expect(mockCache.wrap).toHaveBeenCalledWith(
        `permissions:user:${userId}`,
        expect.any(Function),
        300000
      );
    });

    it('should use cache.wrap for canReadHousehold', async () => {
      const userId = 'test-user-read-household';
      const householdId = 'test-household-id';

      // Use fixture for member household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MEMBER,
        householdId
      );

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const result = await service.canReadHousehold(userId, householdId);

      expect(result).toBe(true);
      expect(mockCacheHelper.getCacheConfig).toHaveBeenCalledWith('permissions', `user:${userId}`);
      expect(mockCache.wrap).toHaveBeenCalledWith(
        `permissions:user:${userId}`,
        expect.any(Function),
        300000
      );
    });

    it('should invalidate user permissions cache', async () => {
      const userId = 'test-user-invalidate';

      await service.invalidateUserPermissions(userId);

      expect(mockCacheHelper.getCacheConfig).toHaveBeenCalledWith('permissions', `user:${userId}`);
      expect(mockCache.del).toHaveBeenCalledWith(`permissions:user:${userId}`);
    });
  });
});
