import { AbilityBuilder, createMongoAbility } from '@casl/ability';
import { HouseholdRole } from '../../../common/enums.js';
import {
  Action,
  Subject,
  AppAbility,
  UserContext,
} from '../permission.types.js';

export class AbilityFactory {
  static createForUser(context: UserContext): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(
      createMongoAbility,
    );

    // Extract household IDs for efficient permission rules
    const allHouseholdIds = context.households.map((h) => h.householdId);
    const managerHouseholdIds = context.households
      .filter((h) => h.role === HouseholdRole.MANAGER)
      .map((h) => h.householdId);
    const memberHouseholdIds = context.households
      .filter((h) => h.role === HouseholdRole.MEMBER)
      .map((h) => h.householdId);
    const aiHouseholdIds = context.households
      .filter((h) => h.role === HouseholdRole.AI)
      .map((h) => h.householdId);

    // Base permissions for all authenticated users
    can('read', 'User', { id: context.userId }); // Can read own profile
    can('create', 'Household'); // All authenticated users can create households

    // All users can update their own profile
    can('update', 'User', { id: context.userId });

    // Users can update users they manage directly (using pre-packed context)
    if (
      context.managedUsers.length > 0 &&
      !(
        aiHouseholdIds.length > 0 &&
        managerHouseholdIds.length === 0 &&
        memberHouseholdIds.length === 0
      )
    ) {
      can('update', 'User', { id: { $in: context.managedUsers } });
    }

    // Household managers can update AI users in households they manage (using pre-packed context)
    if (managerHouseholdIds.length > 0) {
      const manageableAiUsers: string[] = [];
      for (const householdId of managerHouseholdIds) {
        if (context.aiUsers[householdId]) {
          manageableAiUsers.push(...context.aiUsers[householdId]);
        }
      }
      if (manageableAiUsers.length > 0) {
        can('update', 'User', { id: { $in: manageableAiUsers } });
      }
    }

    // Apply consolidated role-based permissions
    this.defineConsolidatedPermissions(
      can,
      cannot,
      context,
      allHouseholdIds,
      managerHouseholdIds,
      memberHouseholdIds,
      aiHouseholdIds,
    );

    return build();
  }

  private static defineConsolidatedPermissions(
    can: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: Record<string, unknown>,
    ) => void,
    cannot: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: Record<string, unknown>,
    ) => void,
    context: UserContext,
    allHouseholdIds: string[],
    managerHouseholdIds: string[],
    memberHouseholdIds: string[],
    aiHouseholdIds: string[],
  ): void {
    const { userId } = context;
    // Household permissions using $in for multiple households
    if (managerHouseholdIds.length > 0) {
      can('manage', 'Household', { id: { $in: managerHouseholdIds } });
    }
    if (memberHouseholdIds.length > 0 || aiHouseholdIds.length > 0) {
      const readHouseholdIds = [...memberHouseholdIds, ...aiHouseholdIds];
      can('read', 'Household', { id: { $in: readHouseholdIds } });
    }

    // HouseholdMember permissions
    if (managerHouseholdIds.length > 0) {
      can('manage', 'HouseholdMember', {
        household_id: { $in: managerHouseholdIds },
        // Managers can't demote other managers (optional business rule)
        role: { $ne: HouseholdRole.MANAGER },
      });
    }
    if (allHouseholdIds.length > 0) {
      can('read', 'HouseholdMember', {
        household_id: { $in: allHouseholdIds },
      });
    }

    // Message permissions with complex conditions
    if (managerHouseholdIds.length > 0) {
      can('manage', 'Message', { household_id: { $in: managerHouseholdIds } });
    }
    if (memberHouseholdIds.length > 0 || aiHouseholdIds.length > 0) {
      const messageHouseholdIds = [...memberHouseholdIds, ...aiHouseholdIds];
      can(['create', 'read'], 'Message', {
        household_id: { $in: messageHouseholdIds },
      });

      // Members can update/delete their own messages only
      if (memberHouseholdIds.length > 0) {
        can(['update', 'delete'], 'Message', {
          $and: [
            { household_id: { $in: memberHouseholdIds } },
            { user_id: userId },
          ],
        });
      }
    }

    // User permissions - using pre-packed context for household members
    if (allHouseholdIds.length > 0) {
      const readableUsers: string[] = [userId]; // Always include own profile

      // Add all household members from pre-packed context
      for (const householdId of allHouseholdIds) {
        if (context.householdMembers[householdId]) {
          readableUsers.push(...context.householdMembers[householdId]);
        }
      }

      // Remove duplicates and allow reading these specific users
      const uniqueReadableUsers = [...new Set(readableUsers)];
      can('read', 'User', { id: { $in: uniqueReadableUsers } });
    }

    // AI-specific restrictions
    if (
      aiHouseholdIds.length > 0 &&
      managerHouseholdIds.length === 0 &&
      memberHouseholdIds.length === 0
    ) {
      // Pure AI users have additional restrictions
      cannot('update', 'User', { id: { $ne: userId } }); // Can't update other users
      cannot(['create', 'update', 'delete'], 'HouseholdMember'); // Can't modify household structure
    }
  }
}
