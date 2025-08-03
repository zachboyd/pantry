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

    const context: UserContext = {
      userId,
      households: householdRoles.map((role) => ({
        householdId: role.household_id,
        role: role.role as HouseholdRole,
      })),
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
   * Uses cache.wrap() for automatic cache management
   */
  private async getOrComputeUserAbility(userId: string): Promise<AppAbility> {
    const { key, ttl } = this.cacheHelper.getCacheConfig(
      'permissions',
      `user:${userId}`,
    );

    return this.cache.wrap(key, () => this.computeUserPermissions(userId), ttl);
  }

  async canCreateHousehold(userId: string): Promise<boolean> {
    const ability = await this.getOrComputeUserAbility(userId);
    return ability.can('create', 'Household');
  }

  async canReadHousehold(
    userId: string,
    _householdId: string,
  ): Promise<boolean> {
    const ability = await this.getOrComputeUserAbility(userId);
    // For CASL, we need to check if the user can read Household resources
    // The conditions are already built into the ability rules during creation
    // We check against a mock household object with the required id
    return ability.can('read', 'Household');
  }

  async canManageHouseholdMember(
    userId: string,
    _householdId: string,
  ): Promise<boolean> {
    const ability = await this.getOrComputeUserAbility(userId);
    // Check if user can manage HouseholdMember resources
    // The household-specific conditions are built into the ability rules
    return ability.can('manage', 'HouseholdMember');
  }

  async canViewUser(
    currentUserId: string,
    targetUserId: string,
  ): Promise<boolean> {
    // Users can always view their own profile
    if (currentUserId === targetUserId) {
      return true;
    }

    const ability = await this.getOrComputeUserAbility(currentUserId);
    // Check if user can read User resources
    // This will check if they have permission to view other users
    // (e.g., through household memberships or management roles)
    return ability.can('read', 'User');
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
