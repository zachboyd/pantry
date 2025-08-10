import { AbilityBuilder, createMongoAbility } from '@casl/ability';
import { packRules } from '@casl/ability/extra';
import { HouseholdRole } from '../../common/enums.js';
import type {
  AppAbility,
  UserContext,
} from '../../modules/permission/permission.types.js';

/**
 * Test fixtures for permission-related data
 */
export class PermissionFixtures {
  /**
   * Creates a test user context for permission testing
   */
  static createUserContext(overrides: Partial<UserContext> = {}): UserContext {
    return {
      userId: 'test-user-id',
      households: [
        {
          householdId: 'test-household-id',
          role: HouseholdRole.MEMBER,
        },
      ],
      managedUsers: [],
      householdMembers: {
        'test-household-id': ['test-user-id'],
      },
      aiUsers: {},
      ...overrides,
    };
  }

  /**
   * Creates a manager user context
   */
  static createManagerUserContext(
    userId: string = 'test-manager-id',
    householdId: string = 'test-household-id',
  ): UserContext {
    return {
      userId,
      households: [
        {
          householdId,
          role: HouseholdRole.MANAGER,
        },
      ],
      managedUsers: [],
      householdMembers: {
        [householdId]: [userId],
      },
      aiUsers: {},
    };
  }

  /**
   * Creates an AI user context
   */
  static createAIUserContext(
    userId: string = 'test-ai-user-id',
    householdId: string = 'test-household-id',
  ): UserContext {
    return {
      userId,
      households: [
        {
          householdId,
          role: HouseholdRole.AI,
        },
      ],
      managedUsers: [],
      householdMembers: {
        [householdId]: [userId],
      },
      aiUsers: {
        [householdId]: [userId],
      },
    };
  }

  /**
   * Creates a user context with multiple household roles
   */
  static createMultiHouseholdUserContext(
    userId: string = 'test-user-id',
  ): UserContext {
    return {
      userId,
      households: [
        {
          householdId: 'household-1',
          role: HouseholdRole.MANAGER,
        },
        {
          householdId: 'household-2',
          role: HouseholdRole.MEMBER,
        },
        {
          householdId: 'household-3',
          role: HouseholdRole.AI,
        },
      ],
      managedUsers: [],
      householdMembers: {
        'household-1': [userId],
        'household-2': [userId],
        'household-3': [userId],
      },
      aiUsers: {
        'household-3': [userId],
      },
    };
  }

  /**
   * Creates a user context with no household memberships
   */
  static createNoHouseholdUserContext(
    userId: string = 'test-user-id',
  ): UserContext {
    return {
      userId,
      households: [],
      managedUsers: [],
      householdMembers: {},
      aiUsers: {},
    };
  }

  /**
   * Creates a basic ability for a member role using MongoDB expressions
   */
  static createMemberAbility(
    userId: string = 'test-user-id',
    householdIds: string[] = ['test-household-id'],
  ): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    // Members can read their own user profile and users in their households
    can('read', 'User', {
      $or: [
        { id: userId },
        { 'household_members.household_id': { $in: householdIds } },
      ],
    });

    // Members can read households they belong to
    can('read', 'Household', { id: { $in: householdIds } });

    // Members can create and read messages in their households
    can(['create', 'read'], 'Message', { household_id: { $in: householdIds } });

    // Members can update/delete their own messages only
    can(['update', 'delete'], 'Message', {
      $and: [{ household_id: { $in: householdIds } }, { user_id: userId }],
    });

    // Members can read household members
    can('read', 'HouseholdMember', { household_id: { $in: householdIds } });

    return build();
  }

  /**
   * Creates a manager ability with full household permissions using MongoDB expressions
   */
  static createManagerAbility(
    userId: string = 'test-manager-id',
    householdIds: string[] = ['test-household-id'],
  ): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    // Base user permissions (own profile)
    can(['read', 'update'], 'User', { id: userId });

    // Manager can read/update users in managed households
    can(['read', 'update'], 'User', {
      $or: [
        { id: userId },
        { 'household_members.household_id': { $in: householdIds } },
        { managed_by: userId },
      ],
    });

    // Managers can manage their households
    can('manage', 'Household', { id: { $in: householdIds } });

    // Managers can manage household members (but not demote other managers)
    can('manage', 'HouseholdMember', {
      household_id: { $in: householdIds },
      role: { $ne: HouseholdRole.MANAGER },
    });

    // Managers can manage all messages in their households
    can('manage', 'Message', { household_id: { $in: householdIds } });

    return build();
  }

  /**
   * Creates an AI ability with limited permissions using MongoDB expressions
   */
  static createAIAbility(
    userId: string = 'test-ai-user-id',
    householdIds: string[] = ['test-household-id'],
  ): AppAbility {
    const { can, cannot, build } = new AbilityBuilder<AppAbility>(
      createMongoAbility,
    );

    // AI can read its own profile and users in its households
    can('read', 'User', {
      $or: [
        { id: userId },
        { 'household_members.household_id': { $in: householdIds } },
      ],
    });

    // AI can read household info
    can('read', 'Household', { id: { $in: householdIds } });
    can('read', 'HouseholdMember', { household_id: { $in: householdIds } });

    // AI can create and read messages but not update/delete
    can(['create', 'read'], 'Message', { household_id: { $in: householdIds } });

    // AI restrictions - cannot modify user profiles or household structure
    cannot('update', 'User', { id: { $ne: userId } });
    cannot(['create', 'update', 'delete'], 'HouseholdMember');

    return build();
  }

  /**
   * Creates an ability with no permissions (user with no household memberships)
   */
  static createNoPermissionsAbility(
    userId: string = 'test-user-id',
  ): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(createMongoAbility);

    // Base permissions for all authenticated users
    can(['read', 'update'], 'User', { id: userId });
    can('create', 'Household'); // All authenticated users can create households

    return build();
  }

  /**
   * Creates packed rules for database storage
   */
  static createPackedRules(ability: AppAbility): string {
    const packedRules = packRules(ability.rules);
    return JSON.stringify(packedRules);
  }

  /**
   * Creates household member database records for testing
   */
  static createHouseholdMemberRecords(
    userId: string = 'test-user-id',
    role: HouseholdRole = HouseholdRole.MEMBER,
    householdId: string = 'test-household-id',
  ) {
    return [
      {
        household_id: householdId,
        role: role,
        user_id: userId,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];
  }

  /**
   * Creates multiple household member records for testing
   */
  static createMultipleHouseholdMemberRecords(userId: string = 'test-user-id') {
    return [
      {
        household_id: 'household-1',
        role: HouseholdRole.MANAGER,
        user_id: userId,
        created_at: new Date(),
        updated_at: new Date(),
      },
      {
        household_id: 'household-2',
        role: HouseholdRole.MEMBER,
        user_id: userId,
        created_at: new Date(),
        updated_at: new Date(),
      },
    ];
  }

  /**
   * Creates user permission record for database
   */
  static createUserPermissionRecord(
    userId: string = 'test-user-id',
    ability: AppAbility = PermissionFixtures.createMemberAbility(),
  ) {
    return {
      id: userId,
      permissions: PermissionFixtures.createPackedRules(ability),
      created_at: new Date(),
      updated_at: new Date(),
    };
  }
}
