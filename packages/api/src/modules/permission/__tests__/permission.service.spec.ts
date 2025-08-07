import { describe, it, expect, beforeEach } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { packRules } from '@casl/ability/extra';
import { PermissionServiceImpl } from '../permission.service.js';
import { PermissionEvaluator } from '../permission-evaluator.js';
import { TOKENS } from '../../../common/tokens.js';
import { HouseholdRole } from '../../../common/enums.js';
import { DatabaseMock } from '../../../test/utils/database-mock.js';
import { CacheManagerMock } from '../../../test/mocks/cache-manager.mock.js';
import { CacheHelperMock } from '../../../test/mocks/cache-helper.mock.js';
import { UserServiceMock } from '../../../test/mocks/user-service.mock.js';
import { PermissionFixtures } from '../../../test/fixtures/permission-fixtures.js';
import type { KyselyMock } from '../../../test/utils/database-mock.js';
import type { CacheManagerMockType } from '../../../test/mocks/cache-manager.mock.js';
import type { CacheHelperMockType } from '../../../test/mocks/cache-helper.mock.js';
import type { UserServiceMockType } from '../../../test/mocks/user-service.mock.js';

describe('PermissionService', () => {
  let service: PermissionServiceImpl;
  let mockDb: KyselyMock;
  let mockCache: CacheManagerMockType;
  let mockCacheHelper: CacheHelperMockType;
  let mockUserService: UserServiceMockType;

  beforeEach(async () => {
    // Create reusable mocks
    mockDb = DatabaseMock.createKyselyMock();
    mockCache = CacheManagerMock.createCacheManagerMock();
    mockCacheHelper = CacheHelperMock.createCacheHelperMock();
    mockUserService = UserServiceMock.createUserServiceMock();

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
        {
          provide: TOKENS.USER.SERVICE,
          useValue: mockUserService,
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
        householdId,
      );

      // Setup database mock to return manager household membership
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined); // For update operation

      const ability = await service.computeUserPermissions(userId);

      // Test that ability was created
      expect(ability).toBeDefined();

      // Verify database calls were made
      expect(mockDb.selectFrom).toHaveBeenCalledWith('household_member');
      expect(mockUserService.updateUserPermissions).toHaveBeenCalledWith(
        userId,
        expect.any(String),
      );
    });

    it('should compute permissions for user with no household roles', async () => {
      const userId = 'isolated-user';

      // Setup database mock to return no household memberships
      mockDb.mockBuilder.mockExecute([]); // No household memberships
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined); // For update operation

      const ability = await service.computeUserPermissions(userId);

      // Test that ability was created
      expect(ability).toBeDefined();
    });
  });

  describe('getUserPermissions', () => {
    it('should return null when user has no cached permissions', async () => {
      const userId = 'user-without-permissions';

      mockDb.mockBuilder.mockExecuteTakeFirst({ permissions: null });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return null when user is not found', async () => {
      const userId = 'non-existent-user';

      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return ability when user has valid cached permissions', async () => {
      const userId = 'user-with-permissions';
      // Use proper packed rules format
      const rules = [{ action: 'create', subject: 'Household' }];
      const mockPermissions = JSON.stringify(packRules(rules));

      mockDb.mockBuilder.mockExecuteTakeFirst({ permissions: mockPermissions });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeDefined();
      // Don't test permission logic here - that's PermissionEvaluator's job
    });

    it('should return null when permissions JSON is invalid', async () => {
      const userId = 'user-with-invalid-permissions';

      mockDb.mockBuilder.mockExecuteTakeFirst({ permissions: 'invalid-json' });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });
  });

  describe('getPermissionEvaluator', () => {
    it('should return PermissionEvaluator instance', async () => {
      const userId = 'test-user';

      mockCacheHelper.getCacheConfig.mockReturnValue({
        key: 'permissions:user:test-user',
        ttl: 300,
      });

      // Mock cache.wrap to call the function and return result
      mockCache.wrap.mockImplementation(
        async (_key: string, fn: () => Promise<unknown>) => {
          return await fn();
        },
      );

      // Use fixture for manager household member records
      const householdMembers = PermissionFixtures.createHouseholdMemberRecords(
        userId,
        HouseholdRole.MANAGER,
        'household-1',
      );

      // Setup database mock
      mockDb.mockBuilder.mockExecute(householdMembers);
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const evaluator = await service.getPermissionEvaluator(userId);

      expect(evaluator).toBeInstanceOf(PermissionEvaluator);
      expect(evaluator.canCreateHousehold()).toBe(true);
      expect(mockCache.wrap).toHaveBeenCalledWith(
        'permissions:user:test-user',
        expect.any(Function),
        300,
      );
    });

    it('should return PermissionEvaluator for user with no household memberships', async () => {
      const userId = 'isolated-user';

      mockCacheHelper.getCacheConfig.mockReturnValue({
        key: 'permissions:user:isolated-user',
        ttl: 300,
      });

      // Mock cache.wrap to call the function and return result
      mockCache.wrap.mockImplementation(
        async (_key: string, fn: () => Promise<unknown>) => {
          return await fn();
        },
      );

      // Setup database mock for user with no household memberships
      mockDb.mockBuilder.mockExecute([]); // No household memberships
      mockDb.mockBuilder.mockExecuteTakeFirst(undefined);

      const evaluator = await service.getPermissionEvaluator(userId);

      expect(evaluator).toBeInstanceOf(PermissionEvaluator);
      expect(evaluator.canCreateHousehold()).toBe(true); // All users can create households
      expect(evaluator.canUpdateUser('other-user')).toBe(false); // Can't update other users
      expect(evaluator.canUpdateUser(userId)).toBe(true); // Can update self
    });
  });

  describe('cache invalidation', () => {
    it('should invalidate user permissions cache', async () => {
      const userId = 'test-user';

      mockCacheHelper.getCacheConfig.mockReturnValue({
        key: 'permissions:user:test-user',
        ttl: 300,
      });

      await service.invalidateUserPermissions(userId);

      expect(mockCache.del).toHaveBeenCalledWith('permissions:user:test-user');
    });

    it('should invalidate permissions for all users in a household', async () => {
      const householdId = 'test-household';
      const userIds = ['user-1', 'user-2', 'user-3'];

      // Mock getting all household members
      mockDb.mockBuilder.mockExecute(userIds.map((id) => ({ user_id: id })));

      // Mock cache config for each user
      userIds.forEach((userId) => {
        mockCacheHelper.getCacheConfig.mockReturnValueOnce({
          key: `permissions:user:${userId}`,
          ttl: 300,
        });
      });

      await service.invalidateHouseholdPermissions(householdId);

      // Verify cache was deleted for each user
      userIds.forEach((userId) => {
        expect(mockCache.del).toHaveBeenCalledWith(
          `permissions:user:${userId}`,
        );
      });
    });
  });
});
