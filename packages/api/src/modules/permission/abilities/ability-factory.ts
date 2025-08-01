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
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    // Extract household IDs for efficient permission rules
    const allHouseholdIds = context.households.map(h => h.householdId);
    const managerHouseholdIds = context.households
      .filter(h => h.role === HouseholdRole.MANAGER)
      .map(h => h.householdId);
    const memberHouseholdIds = context.households
      .filter(h => h.role === HouseholdRole.MEMBER)
      .map(h => h.householdId);
    const aiHouseholdIds = context.households
      .filter(h => h.role === HouseholdRole.AI)
      .map(h => h.householdId);

    // Base permissions for all authenticated users
    can('read', 'User', { id: context.userId }); // Can read own profile
    
    // Only non-AI users can update their profile by default
    // AI users get restricted update permissions later
    if (aiHouseholdIds.length === 0 || managerHouseholdIds.length > 0 || memberHouseholdIds.length > 0) {
      can('update', 'User', { id: context.userId }); // Can update own profile
    }

    // Apply consolidated role-based permissions
    this.defineConsolidatedPermissions(
      can, 
      cannot, 
      context.userId,
      allHouseholdIds,
      managerHouseholdIds,
      memberHouseholdIds,
      aiHouseholdIds
    );

    return build();
  }

  private static defineConsolidatedPermissions(
    can: (action: Action | Action[], subject: Subject | Subject[], conditions?: any) => void,
    cannot: (action: Action | Action[], subject: Subject | Subject[], conditions?: any) => void,
    userId: string,
    allHouseholdIds: string[],
    managerHouseholdIds: string[],
    memberHouseholdIds: string[],
    aiHouseholdIds: string[]
  ): void {
    
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
        role: { $ne: HouseholdRole.MANAGER }
      });
    }
    if (allHouseholdIds.length > 0) {
      can('read', 'HouseholdMember', { household_id: { $in: allHouseholdIds } });
    }

    // Message permissions with complex conditions
    if (managerHouseholdIds.length > 0) {
      can('manage', 'Message', { household_id: { $in: managerHouseholdIds } });
    }
    if (memberHouseholdIds.length > 0 || aiHouseholdIds.length > 0) {
      const messageHouseholdIds = [...memberHouseholdIds, ...aiHouseholdIds];
      can(['create', 'read'], 'Message', { household_id: { $in: messageHouseholdIds } });
      
      // Members can update/delete their own messages only
      if (memberHouseholdIds.length > 0) {
        can(['update', 'delete'], 'Message', {
          $and: [
            { household_id: { $in: memberHouseholdIds } },
            { user_id: userId }
          ]
        });
      }
    }

    // Pantry permissions
    if (managerHouseholdIds.length > 0) {
      can('manage', 'Pantry', { household_id: { $in: managerHouseholdIds } });
    }
    if (allHouseholdIds.length > 0) {
      can('read', 'Pantry', { household_id: { $in: allHouseholdIds } });
    }

    // User permissions - properly restricted to household members
    if (allHouseholdIds.length > 0) {
      // All household members can read users in same households
      can('read', 'User', {
        $or: [
          { id: userId }, // Own profile
          { 'household_members.household_id': { $in: allHouseholdIds } }
        ]
      });
      
      // Additional update permissions for managers
      if (managerHouseholdIds.length > 0) {
        can('update', 'User', {
          $or: [
            { id: userId }, // Always own profile
            { 'household_members.household_id': { $in: managerHouseholdIds } }
          ]
        });
      }
    }

    // AI-specific restrictions
    if (aiHouseholdIds.length > 0 && managerHouseholdIds.length === 0 && memberHouseholdIds.length === 0) {
      // Pure AI users have additional restrictions
      cannot('update', 'User', { id: { $ne: userId } }); // Can't update other users
      cannot(['create', 'update', 'delete'], 'HouseholdMember'); // Can't modify household structure
    }
  }
}
