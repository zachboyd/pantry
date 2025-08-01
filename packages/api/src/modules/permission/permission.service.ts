import { Injectable, Inject } from '@nestjs/common';
import { Kysely } from 'kysely';
import { AbilityBuilder, PureAbility } from '@casl/ability';
import { packRules, unpackRules } from '@casl/ability/extra';
import { DB, Json } from '../../generated/database.js';
import { TOKENS } from '../../common/tokens.js';
import { HouseholdRole } from '../../common/enums.js';
import {
  PermissionService,
  AppAbility,
  UserContext,
} from './permission.types.js';
import { AbilityFactory } from './abilities/ability-factory.js';

@Injectable()
export class PermissionServiceImpl implements PermissionService {
  constructor(
    @Inject(TOKENS.DATABASE.CONNECTION)
    private readonly db: Kysely<DB>,
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

      // Create ability from unpacked rules
      return new PureAbility(rules, {
        conditionsMatcher: (conditions) => (object) => {
          if (!conditions) return true;

          for (const [key, value] of Object.entries(conditions)) {
            if (key.includes('.')) {
              // Handle nested property access like 'household_members.household_id'
              const keys = key.split('.');
              let current = object;
              for (const k of keys) {
                if (current?.[k] === undefined) return false;
                current = current[k];
              }
              if (current !== value) return false;
            } else if (typeof value === 'object' && value !== null) {
              // Handle special operators like { $exists: true }
              if ('$exists' in value) {
                const exists =
                  object[key] !== undefined && object[key] !== null;
                if (exists !== value.$exists) return false;
              }
            } else {
              // Simple property match
              if (object[key] !== value) return false;
            }
          }
          return true;
        },
      });
    } catch {
      return null;
    }
  }
}
