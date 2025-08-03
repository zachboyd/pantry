// No need to import - we'll use ReturnType

/**
 * Utility functions for GraphQL integration testing
 */
export class GraphQLTestUtils {
  /**
   * Common GraphQL queries for testing
   */
  static readonly QUERIES = {
    GET_USER: `
      query GetUser($input: GetUserInput!) {
        user(input: $input) {
          id
          auth_user_id
          email
          first_name
          last_name
          display_name
          avatar_url
          phone
          birth_date
          managed_by
          relationship_to_manager
          created_at
          updated_at
        }
      }
    `,

    GET_CURRENT_USER: `
      query GetCurrentUser {
        currentUser {
          id
          auth_user_id
          email
          first_name
          last_name
          display_name
          avatar_url
          phone
          birth_date
          managed_by
          relationship_to_manager
          created_at
          updated_at
        }
      }
    `,

    CREATE_HOUSEHOLD: `
      mutation CreateHousehold($input: CreateHouseholdInput!) {
        createHousehold(input: $input) {
          id
          name
          description
          created_by
          created_at
          updated_at
        }
      }
    `,

    GET_HOUSEHOLD: `
      query GetHousehold($input: GetHouseholdInput!) {
        household(input: $input) {
          id
          name
          description
          created_by
          created_at
          updated_at
        }
      }
    `,

    ADD_HOUSEHOLD_MEMBER: `
      mutation AddHouseholdMember($input: AddHouseholdMemberInput!) {
        addHouseholdMember(input: $input) {
          id
          household_id
          user_id
          role
          joined_at
        }
      }
    `,

    REMOVE_HOUSEHOLD_MEMBER: `
      mutation RemoveHouseholdMember($input: RemoveHouseholdMemberInput!) {
        removeHouseholdMember(input: $input)
      }
    `,

    CHANGE_HOUSEHOLD_MEMBER_ROLE: `
      mutation ChangeHouseholdMemberRole($input: ChangeHouseholdMemberRoleInput!) {
        changeHouseholdMemberRole(input: $input) {
          id
          household_id
          user_id
          role
          joined_at
        }
      }
    `,
  };

  /**
   * Execute a GraphQL query and return the parsed response
   */
  static async executeQuery(
    request: ReturnType<typeof import('supertest')>,
    query: string,
    variables?: Record<string, unknown>,
    headers?: Record<string, string>,
  ) {
    const response = await request
      .post('/graphql')
      .set('Content-Type', 'application/json')
      .set(headers || {})
      .send({
        query,
        variables,
      });

    return {
      status: response.status,
      body: response.body,
      data: response.body.data,
      errors: response.body.errors,
    };
  }

  /**
   * Execute a GraphQL query with authentication
   */
  static async executeAuthenticatedQuery(
    request: ReturnType<typeof import('supertest')>,
    query: string,
    sessionToken: string,
    variables?: Record<string, unknown>,
  ) {
    return this.executeQuery(request, query, variables, {
      Cookie: `pantry.session_token=${sessionToken}`,
    });
  }

  /**
   * Assert that a GraphQL response has no errors
   */
  static assertNoErrors(response: { errors?: unknown[] }) {
    if (response.errors) {
      throw new Error(
        `GraphQL errors: ${JSON.stringify(response.errors, null, 2)}`,
      );
    }
  }

  /**
   * Assert that a GraphQL response has specific errors
   */
  static assertHasErrors(
    response: { errors?: unknown[] },
    expectedErrorCount = 1,
  ) {
    if (!response.errors || response.errors.length !== expectedErrorCount) {
      throw new Error(
        `Expected ${expectedErrorCount} GraphQL errors, got: ${JSON.stringify(response.errors, null, 2)}`,
      );
    }
  }

  /**
   * Assert that a GraphQL response has an error with specific message
   */
  static assertErrorMessage(
    response: { errors?: Array<{ message: string }> },
    expectedMessage: string,
  ) {
    this.assertHasErrors(response);
    const hasExpectedMessage = response.errors!.some((error) =>
      error.message.includes(expectedMessage),
    );
    if (!hasExpectedMessage) {
      throw new Error(
        `Expected error message "${expectedMessage}", got: ${JSON.stringify(response.errors, null, 2)}`,
      );
    }
  }

  /**
   * Create test input for user queries
   */
  static createGetUserInput(userId: string) {
    return { input: { id: userId } };
  }

  /**
   * Create test input for household creation
   */
  static createHouseholdInput(name: string, description?: string) {
    return {
      input: {
        name,
        ...(description && { description }),
      },
    };
  }

  /**
   * Create test input for household queries
   */
  static createGetHouseholdInput(householdId: string) {
    return { input: { id: householdId } };
  }

  /**
   * Create test input for adding household members
   */
  static createAddHouseholdMemberInput(
    householdId: string,
    userId: string,
    role: string,
  ) {
    return {
      input: {
        householdId,
        userId,
        role,
      },
    };
  }

  /**
   * Create test input for removing household members
   */
  static createRemoveHouseholdMemberInput(householdId: string, userId: string) {
    return {
      input: {
        householdId,
        userId,
      },
    };
  }

  /**
   * Create test input for changing household member roles
   */
  static createChangeHouseholdMemberRoleInput(
    householdId: string,
    userId: string,
    newRole: string,
  ) {
    return {
      input: {
        householdId,
        userId,
        newRole,
      },
    };
  }
}
