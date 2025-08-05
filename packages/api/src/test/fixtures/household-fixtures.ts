import { v4 as uuidv4 } from 'uuid';
import type { Kysely } from 'kysely';
import type { DB, HouseholdRole } from '../../generated/database.js';
import { HouseholdRole as HouseholdRoleEnum } from '../../common/enums.js';

/**
 * Test fixtures for household-related data
 */
export class HouseholdTestFixtures {
  /**
   * Creates a basic test household
   */
  static createBasicHousehold(
    overrides: {
      id?: string;
      name?: string;
      description?: string;
      created_by?: string;
    } = {},
  ) {
    return {
      id: overrides.id || uuidv4(),
      name: overrides.name || 'Test Family',
      description: overrides.description || 'A test household',
      created_by: overrides.created_by || 'test-user-id',
      created_at: new Date(),
      updated_at: new Date(),
    };
  }

  /**
   * Creates a household member record
   */
  static createHouseholdMember(
    overrides: {
      id?: string;
      household_id?: string;
      user_id?: string;
      role?: HouseholdRole;
    } = {},
  ) {
    return {
      id: overrides.id || uuidv4(),
      household_id: overrides.household_id || 'test-household-id',
      user_id: overrides.user_id || 'test-user-id',
      role: overrides.role || HouseholdRoleEnum.MEMBER,
      joined_at: new Date(),
    };
  }

  /**
   * Creates a complete household scenario with manager and members
   */
  static createFamilyHousehold(
    managerId: string,
    memberIds: string[] = [],
    householdOverrides: { name?: string; description?: string } = {},
  ) {
    const householdId = uuidv4();
    const household = this.createBasicHousehold({
      id: householdId,
      created_by: managerId,
      ...householdOverrides,
    });

    const members = [
      // Manager
      this.createHouseholdMember({
        household_id: householdId,
        user_id: managerId,
        role: HouseholdRoleEnum.MANAGER,
      }),
      // Members
      ...memberIds.map((userId) =>
        this.createHouseholdMember({
          household_id: householdId,
          user_id: userId,
          role: HouseholdRoleEnum.MEMBER,
        }),
      ),
    ];

    return {
      household,
      members,
      managerId,
      memberIds,
      householdId,
    };
  }

  /**
   * Creates a household with AI assistant
   */
  static createHouseholdWithAI(
    managerId: string,
    aiUserId: string,
    memberIds: string[] = [],
  ) {
    const householdId = uuidv4();
    const household = this.createBasicHousehold({
      id: householdId,
      created_by: managerId,
      name: 'AI-Enabled Household',
    });

    const members = [
      // Manager
      this.createHouseholdMember({
        household_id: householdId,
        user_id: managerId,
        role: HouseholdRoleEnum.MANAGER,
      }),
      // AI Assistant
      this.createHouseholdMember({
        household_id: householdId,
        user_id: aiUserId,
        role: HouseholdRoleEnum.AI,
      }),
      // Members
      ...memberIds.map((userId) =>
        this.createHouseholdMember({
          household_id: householdId,
          user_id: userId,
          role: HouseholdRoleEnum.MEMBER,
        }),
      ),
    ];

    return {
      household,
      members,
      managerId,
      aiUserId,
      memberIds,
      householdId,
    };
  }

  /**
   * Creates multiple households for a user (user belongs to multiple households)
   */
  static createMultiHouseholdUser(userId: string, householdCount: number = 2) {
    const households = [];
    const members = [];

    for (let i = 0; i < householdCount; i++) {
      const householdId = uuidv4();
      const isManager = i === 0; // First household: user is manager, others: member

      const household = this.createBasicHousehold({
        id: householdId,
        name: `Household ${i + 1}`,
        created_by: isManager ? userId : `other-user-${i}`,
      });

      const member = this.createHouseholdMember({
        household_id: householdId,
        user_id: userId,
        role: isManager ? HouseholdRoleEnum.MANAGER : HouseholdRoleEnum.MEMBER,
      });

      households.push(household);
      members.push(member);
    }

    return {
      households,
      members,
      userId,
    };
  }

  /**
   * Inserts household and members into database
   */
  static async insertHouseholdScenario(
    db: Kysely<DB>,
    scenario: {
      household: ReturnType<typeof HouseholdTestFixtures.createBasicHousehold>;
      members: ReturnType<typeof HouseholdTestFixtures.createHouseholdMember>[];
    },
  ) {
    // Insert household
    await db.insertInto('household').values(scenario.household).execute();

    // Insert members
    if (scenario.members.length > 0) {
      await db
        .insertInto('household_member')
        .values(scenario.members)
        .execute();
    }

    return scenario;
  }

  /**
   * Creates a permission test scenario - user trying to access another household
   */
  static createPermissionTestScenario() {
    const userAId = uuidv4();
    const userBId = uuidv4();

    // User A's household (user A is manager)
    const householdA = this.createFamilyHousehold(userAId, [], {
      name: 'User A Household',
    });

    // User B's household (user B is manager)
    const householdB = this.createFamilyHousehold(userBId, [], {
      name: 'User B Household',
    });

    return {
      userA: {
        userId: userAId,
        household: householdA.household,
        members: householdA.members,
      },
      userB: {
        userId: userBId,
        household: householdB.household,
        members: householdB.members,
      },
    };
  }

  /**
   * Clean up household-related test data
   */
  static async cleanupHouseholdData(db: Kysely<DB>, householdIds: string[]) {
    if (householdIds.length === 0) return;

    // Delete in order due to foreign key constraints
    await db
      .deleteFrom('household_member')
      .where('household_id', 'in', householdIds)
      .execute();

    await db.deleteFrom('household').where('id', 'in', householdIds).execute();
  }
}
