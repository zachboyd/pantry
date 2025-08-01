import { AbilityBuilder, PureAbility } from '@casl/ability';
import { packRules } from '@casl/ability/extra';
import { HouseholdRole } from '../../common/enums.js';
import type { AppAbility, UserContext } from '../../modules/permission/permission.types.js';

/**
 * Test fixtures for permission-related data
 */
export class PermissionFixtures {
  /**
   * Creates a test user context for permission testing
   */
  static createUserContext(
    overrides: Partial<UserContext> = {}
  ): UserContext {
    return {
      userId: 'test-user-id',
      households: [
        {
          householdId: 'test-household-id',
          role: HouseholdRole.MEMBER,
        },
      ],
      ...overrides,
    };
  }

  /**
   * Creates a manager user context
   */
  static createManagerUserContext(
    userId: string = 'test-manager-id',
    householdId: string = 'test-household-id'
  ): UserContext {
    return {
      userId,
      households: [
        {
          householdId,
          role: HouseholdRole.MANAGER,
        },
      ],
    };
  }

  /**
   * Creates an AI user context
   */
  static createAIUserContext(
    userId: string = 'test-ai-user-id',
    householdId: string = 'test-household-id'
  ): UserContext {
    return {
      userId,
      households: [
        {
          householdId,
          role: HouseholdRole.AI,
        },
      ],
    };
  }

  /**
   * Creates a user context with multiple household roles
   */
  static createMultiHouseholdUserContext(
    userId: string = 'test-user-id'
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
    };
  }

  /**
   * Creates a user context with no household memberships
   */
  static createNoHouseholdUserContext(
    userId: string = 'test-user-id'
  ): UserContext {
    return {
      userId,
      households: [],
    };
  }

  /**
   * Creates a basic ability for a member role
   */
  static createMemberAbility(): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(PureAbility);
    
    // Members can read their own user profile
    can('read', 'User');
    
    // Members can read household info they belong to
    can('read', 'Household');
    
    // Members can create and read messages in their households
    can('create', 'Message');
    can('read', 'Message');
    
    // Members can read household members
    can('read', 'HouseholdMember');

    return build({
      conditionsMatcher: (conditions) => (object) => {
        if (!conditions) return true;
        for (const [key, value] of Object.entries(conditions)) {
          if (object[key] !== value) return false;
        }
        return true;
      },
    });
  }

  /**
   * Creates a manager ability with full household permissions
   */
  static createManagerAbility(): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(PureAbility);
    
    // Managers have all member permissions plus management capabilities
    can('manage', 'Household');
    can('read', 'User');
    can('manage', 'Message');
    can('manage', 'HouseholdMember');
    can('read', 'Pantry');
    can('manage', 'Attachment');

    return build({
      conditionsMatcher: (conditions) => (object) => {
        if (!conditions) return true;
        for (const [key, value] of Object.entries(conditions)) {
          if (object[key] !== value) return false;
        }
        return true;
      },
    });
  }

  /**
   * Creates an AI ability with limited permissions
   */
  static createAIAbility(): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(PureAbility);
    
    // AI can read household info
    can('read', 'Household');
    
    // AI can create messages but cannot manage other users' messages
    can('create', 'Message');
    can('read', 'Message');

    return build({
      conditionsMatcher: (conditions) => (object) => {
        if (!conditions) return true;
        for (const [key, value] of Object.entries(conditions)) {
          if (object[key] !== value) return false;
        }
        return true;
      },
    });
  }

  /**
   * Creates an ability with no permissions (user with no household memberships)
   */
  static createNoPermissionsAbility(): AppAbility {
    const { can, build } = new AbilityBuilder<AppAbility>(PureAbility);
    
    // Only own profile access
    can('read', 'User');

    return build({
      conditionsMatcher: (conditions) => (object) => {
        if (!conditions) return true;
        for (const [key, value] of Object.entries(conditions)) {
          if (object[key] !== value) return false;
        }
        return true;
      },
    });
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
    householdId: string = 'test-household-id'
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
  static createMultipleHouseholdMemberRecords(
    userId: string = 'test-user-id'
  ) {
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
    ability: AppAbility = PermissionFixtures.createMemberAbility()
  ) {
    return {
      id: userId,
      permissions: PermissionFixtures.createPackedRules(ability),
      created_at: new Date(),
      updated_at: new Date(),
    };
  }
}