import { Injectable, Inject } from '@nestjs/common';
import { Kysely } from 'kysely';
import { createMongoAbility } from '@casl/ability';
import { packRules, unpackRules } from '@casl/ability/extra';
import type { Cache } from 'cache-manager';
import { DB, Json } from '../../generated/database.js';
import { TOKENS } from '../../common/tokens.js';
import { HouseholdRole } from '../../common/enums.js';
import {
  PermissionService,
  AppAbility,
  UserContext,
} from './permission.types.js';
import { AbilityFactory } from './abilities/ability-factory.js';
import { PermissionEvaluator } from './permission-evaluator.js';
import type { CacheHelper } from '../cache/cache.helper.js';

@Injectable()
export class PermissionServiceImpl implements PermissionService {
  constructor(
    @Inject(TOKENS.DATABASE.CONNECTION)
    private readonly db: Kysely<DB>,
    @Inject(TOKENS.CACHE.MANAGER)
    private readonly cache: Cache,
    @Inject(TOKENS.CACHE.HELPER)
    private readonly cacheHelper: CacheHelper,
  ) {}

  async computeUserPermissions(userId: string): Promise<AppAbility> {
    // Get user's household roles
    const householdRoles = await this.db
      .selectFrom('household_member')
      .select(['household_id', 'role'])
      .where('user_id', '=', userId)
      .execute();

    // Get users managed directly by this user
    const managedUsers = await this.db
      .selectFrom('user')
      .select('id')
      .where('managed_by', '=', userId)
      .execute();

    // Get all household members for households this user belongs to
    const householdIds = householdRoles.map((role) => role.household_id);
    const householdMembersData =
      householdIds.length > 0
        ? await this.db
            .selectFrom('user')
            .innerJoin(
              'household_member',
              'user.id',
              'household_member.user_id',
            )
            .select(['household_member.household_id', 'user.id', 'user.is_ai'])
            .where('household_member.household_id', 'in', householdIds)
            .execute()
        : [];

    // Group household members by household ID
    const householdMembers: Record<string, string[]> = {};
    const aiUsers: Record<string, string[]> = {};

    for (const member of householdMembersData) {
      const householdId = member.household_id;

      if (!householdMembers[householdId]) {
        householdMembers[householdId] = [];
      }
      if (!aiUsers[householdId]) {
        aiUsers[householdId] = [];
      }

      householdMembers[householdId].push(member.id);

      if (member.is_ai) {
        aiUsers[householdId].push(member.id);
      }
    }

    const context: UserContext = {
      userId,
      households: householdRoles.map((role) => ({
        householdId: role.household_id,
        role: role.role as HouseholdRole,
      })),
      managedUsers: managedUsers.map((user) => user.id),
      householdMembers,
      aiUsers,
    };

    const ability = AbilityFactory.createForUser(context);

    // Update stored permissions
    await this.updateUserPermissions(userId, ability);

    return ability;
  }

  private async updateUserPermissions(
    userId: string,
    ability: AppAbility,
  ): Promise<void> {
    const packedRules = packRules(ability.rules);

    await this.db
      .updateTable('user')
      .set({
        permissions: JSON.stringify(packedRules) as Json,
        updated_at: new Date(),
      })
      .where('id', '=', userId)
      .execute();
  }

  async getUserPermissions(userId: string): Promise<AppAbility | null> {
    const user = await this.db
      .selectFrom('user')
      .select('permissions')
      .where('id', '=', userId)
      .executeTakeFirst();

    if (!user?.permissions) {
      return null;
    }

    try {
      const packedRules = JSON.parse(user.permissions as string);
      const rules = unpackRules(packedRules);

      // Create ability from unpacked rules using createMongoAbility
      // Type assertion needed because rules from serialized storage lose their original types
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      return createMongoAbility(rules as any) as AppAbility;
    } catch {
      return null;
    }
  }

  /**
   * Centralized method to get or compute user abilities with caching
   * Caches serialized rules instead of ability objects to avoid serialization issues
   */
  private async getOrComputeUserAbility(userId: string): Promise<AppAbility> {
    const { key, ttl } = this.cacheHelper.getCacheConfig(
      'permissions',
      `user:${userId}`,
    );

    // Cache serialized rules instead of ability objects
    const cachedRules = await this.cache.wrap(
      key,
      async () => {
        // First try to get from database storage
        const storedAbility = await this.getUserPermissions(userId);
        if (storedAbility) {
          // Return the serialized rules for caching
          return packRules(storedAbility.rules);
        }

        // If not in database, compute fresh
        const freshAbility = await this.computeUserPermissions(userId);
        return packRules(freshAbility.rules);
      },
      ttl,
    );

    // Reconstruct ability from cached rules
    const rules = unpackRules(cachedRules);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return createMongoAbility(rules as any) as AppAbility;
  }

  /**
   * Get a PermissionEvaluator for the specified user.
   * This is the primary method for checking permissions throughout the application.
   *
   * @example
   * const evaluator = await permissionService.getPermissionEvaluator(userId);
   * if (evaluator.canUpdateUser(targetUserId)) {
   *   // perform update
   * }
   */
  async getPermissionEvaluator(userId: string): Promise<PermissionEvaluator> {
    const ability = await this.getOrComputeUserAbility(userId);
    return new PermissionEvaluator(ability);
  }

  /**
   * Invalidate user permissions cache when household membership changes
   */
  async invalidateUserPermissions(userId: string): Promise<void> {
    const { key } = this.cacheHelper.getCacheConfig(
      'permissions',
      `user:${userId}`,
    );
    await this.cache.del(key);
  }

  /**
   * Invalidate permissions for all users in a household
   */
  async invalidateHouseholdPermissions(householdId: string): Promise<void> {
    // Get all users in the household
    const members = await this.db
      .selectFrom('household_member')
      .select('user_id')
      .where('household_id', '=', householdId)
      .execute();

    // Invalidate each user's permissions
    for (const member of members) {
      await this.invalidateUserPermissions(member.user_id);
    }
  }
}
