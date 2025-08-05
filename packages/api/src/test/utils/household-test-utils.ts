import { expect } from 'vitest';

/**
 * Household-specific testing utilities and assertions
 */
export class HouseholdTestUtils {
  /**
   * Assert that a household member has the expected structure
   */
  static assertHouseholdMember(
    member: unknown,
    expectedValues: {
      household_id?: string;
      user_id?: string;
      role?: string;
    } = {},
  ) {
    expect(member).toHaveProperty('id');
    expect(member).toHaveProperty('household_id');
    expect(member).toHaveProperty('user_id');
    expect(member).toHaveProperty('role');
    expect(member).toHaveProperty('joined_at');

    const memberObj = member as Record<string, unknown>;

    if (expectedValues.household_id) {
      expect(memberObj.household_id).toBe(expectedValues.household_id);
    }
    if (expectedValues.user_id) {
      expect(memberObj.user_id).toBe(expectedValues.user_id);
    }
    if (expectedValues.role) {
      expect(memberObj.role).toBe(expectedValues.role);
    }
  }

  /**
   * Assert that a household has the expected structure
   */
  static assertHousehold(
    household: unknown,
    expectedValues: {
      name?: string;
      description?: string;
      created_by?: string;
    } = {},
  ) {
    expect(household).toHaveProperty('id');
    expect(household).toHaveProperty('name');
    expect(household).toHaveProperty('created_by');
    expect(household).toHaveProperty('created_at');
    expect(household).toHaveProperty('updated_at');

    const householdObj = household as Record<string, unknown>;

    if (expectedValues.name) {
      expect(householdObj.name).toBe(expectedValues.name);
    }
    if (expectedValues.description !== undefined) {
      expect(householdObj.description).toBe(expectedValues.description);
    }
    if (expectedValues.created_by) {
      expect(householdObj.created_by).toBe(expectedValues.created_by);
    }
  }

  /**
   * Assert that household members list contains expected members
   */
  static assertHouseholdMembers(
    members: unknown[],
    expectedMembers: Array<{
      user_id?: string;
      role?: string;
    }>,
  ) {
    expect(Array.isArray(members)).toBe(true);
    expect(members).toHaveLength(expectedMembers.length);

    expectedMembers.forEach((expectedMember, index) => {
      this.assertHouseholdMember(members[index], expectedMember);
    });
  }

  /**
   * Assert that user has specific role in household members list
   */
  static assertUserRole(
    members: unknown[],
    userId: string,
    expectedRole: string,
  ) {
    const userMember = members.find(
      (member: unknown) =>
        typeof member === 'object' &&
        member !== null &&
        'user_id' in member &&
        (member as { user_id: string }).user_id === userId,
    ) as { user_id: string; role: string } | undefined;

    expect(userMember).toBeDefined();
    expect(userMember?.role).toBe(expectedRole);
  }

  /**
   * Assert that response contains permission error
   */
  static assertPermissionError(response: {
    body: { errors?: Array<{ message: string }> };
  }) {
    expect(response.body.errors).toBeDefined();
    expect(response.body.errors!.length).toBeGreaterThan(0);

    const errorMessage = response.body.errors![0].message.toLowerCase();
    expect(
      errorMessage.includes('permission') ||
        errorMessage.includes('forbidden') ||
        errorMessage.includes('access'),
    ).toBe(true);
  }
}
