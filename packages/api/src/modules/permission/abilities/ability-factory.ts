import { AbilityBuilder, PureAbility } from '@casl/ability';
import { HouseholdRole } from '../../../common/enums.js';
import {
  Action,
  Subject,
  AppAbility,
  UserContext,
} from '../permission.types.js';

export class AbilityFactory {
  static createForUser(context: UserContext): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(PureAbility);

    // Base permissions for all authenticated users
    can('read', 'User', { id: context.userId }); // Can read own profile
    can('update', 'User', { id: context.userId }); // Can update own profile

    // Apply role-based permissions for each household
    context.households.forEach(({ householdId, role }) => {
      switch (role) {
        case HouseholdRole.MANAGER:
          this.defineManagerPermissions(can, cannot, householdId);
          break;
        case HouseholdRole.MEMBER:
          this.defineMemberPermissions(can, cannot, householdId);
          break;
        case HouseholdRole.AI:
          this.defineAIPermissions(can, cannot, householdId);
          break;
      }
    });

    return build({
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
              const exists = object[key] !== undefined && object[key] !== null;
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
  }

  private static defineManagerPermissions(
    can: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    cannot: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    householdId: string,
  ): void {
    // Managers can manage their household
    can('manage', 'Household', { id: householdId });

    // Managers can manage household members
    can('manage', 'HouseholdMember', { household_id: householdId });

    // Managers can manage all messages in their household
    can('manage', 'Message', { household_id: householdId });

    // Managers can manage pantries in their household
    can('manage', 'Pantry', { household_id: householdId });

    // Managers can manage attachments in their household
    can('manage', 'Attachment', { household_id: householdId });

    // Managers can read/update users in their household
    can(['read', 'update'], 'User', {
      'household_members.household_id': householdId,
    });
  }

  private static defineMemberPermissions(
    can: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    cannot: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    householdId: string,
  ): void {
    // Members can read their household
    can('read', 'Household', { id: householdId });

    // Members can read household members
    can('read', 'HouseholdMember', { household_id: householdId });

    // Members can create and read messages, update/delete their own
    can('create', 'Message', { household_id: householdId });
    can('read', 'Message', { household_id: householdId });
    can(['update', 'delete'], 'Message', {
      household_id: householdId,
      user_id: { $exists: true }, // Only messages with user_id (not AI messages)
    });

    // Members can read pantries
    can('read', 'Pantry', { household_id: householdId });

    // Members can create and read attachments, manage their own
    can('create', 'Attachment', { household_id: householdId });
    can('read', 'Attachment', { household_id: householdId });
    can(['update', 'delete'], 'Attachment', {
      household_id: householdId,
      user_id: { $exists: true },
    });

    // Members can read other users in their household
    can('read', 'User', {
      'household_members.household_id': householdId,
    });
  }

  private static defineAIPermissions(
    can: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    cannot: (
      action: Action | Action[],
      subject: Subject | Subject[],
      conditions?: any,
    ) => void,
    householdId: string,
  ): void {
    // AI can read household data
    can('read', 'Household', { id: householdId });
    can('read', 'HouseholdMember', { household_id: householdId });

    // AI can create and read messages (but not update/delete)
    can('create', 'Message', { household_id: householdId });
    can('read', 'Message', { household_id: householdId });

    // AI can read pantries
    can('read', 'Pantry', { household_id: householdId });

    // AI can read attachments
    can('read', 'Attachment', { household_id: householdId });

    // AI can read users in the household
    can('read', 'User', {
      'household_members.household_id': householdId,
    });

    // AI cannot modify user profiles or household structure
    cannot('update', 'User');
    cannot(['create', 'update', 'delete'], 'HouseholdMember');
  }
}
