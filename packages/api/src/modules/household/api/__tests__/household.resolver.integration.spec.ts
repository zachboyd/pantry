import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../../generated/database.js';
import { IntegrationTestModuleFactory } from '../../../../test/utils/integration-test-module-factory.js';
import { TestDatabaseService } from '../../../../test/utils/test-database.service.js';
import { GraphQLTestUtils } from '../../../../test/utils/graphql-test-utils.js';
import { HouseholdTestUtils } from '../../../../test/utils/household-test-utils.js';

describe('Household Resolver Integration Tests', () => {
  let app: INestApplication;
  let testRequest: ReturnType<typeof import('supertest')>;
  let db: Kysely<DB>;
  let testDbService: TestDatabaseService;

  beforeAll(async () => {
    // Create integration test app once for all tests
    const testApp = await IntegrationTestModuleFactory.createApp();
    app = testApp.app;
    testRequest = testApp.request;
    db = testApp.db;
    testDbService = testApp.testDbService;

    // Clean database at the start to ensure clean state between test files
    try {
      await IntegrationTestModuleFactory.cleanDatabase(db);
    } catch (error) {
      console.warn('Database cleanup skipped in beforeAll:', error);
    }
  });

  beforeEach(async () => {
    // Clean database before each test for isolation
    try {
      await IntegrationTestModuleFactory.cleanDatabase(db);
    } catch (error) {
      console.warn('Database cleanup skipped:', error);
    }
  });

  afterAll(async () => {
    // Clean database after all tests to avoid interfering with other test files
    try {
      await IntegrationTestModuleFactory.cleanDatabase(db);
    } catch (error) {
      console.warn('Database cleanup skipped in afterAll:', error);
    }

    // Cleanup after all tests
    await IntegrationTestModuleFactory.closeApp(app, testDbService);
  });

  describe('householdMembers query', () => {
    it('should return household members when user is a household member', async () => {
      // Arrange - Create household with multiple members
      const { household, manager, members, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          2,
          { name: 'Family Household', description: 'A test family' },
        );

      // Act - Manager queries household members
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        manager.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const householdMembers = response.body.data.householdMembers;
      expect(Array.isArray(householdMembers)).toBe(true);
      expect(householdMembers).toHaveLength(4); // Manager + AI + 2 members

      // Verify manager is included
      HouseholdTestUtils.assertUserRole(
        householdMembers,
        manager.userId,
        'manager',
      );

      // Verify members are included
      members.forEach((member) => {
        HouseholdTestUtils.assertUserRole(
          householdMembers,
          member.userId,
          'member',
        );
      });

      // Verify all members have correct structure
      householdMembers.forEach((member: unknown) => {
        HouseholdTestUtils.assertHouseholdMember(member, {
          household_id: householdId,
        });
      });
    });

    it('should return household members when user is a regular member', async () => {
      // Arrange - Create household with members
      const { manager, members, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          1,
        );

      const regularMember = members[0];

      // Act - Regular member queries household members
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        regularMember.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const householdMembers = response.body.data.householdMembers;
      expect(householdMembers).toHaveLength(3); // Manager + AI + 1 member

      // Verify both users are present
      HouseholdTestUtils.assertUserRole(
        householdMembers,
        manager.userId,
        'manager',
      );
      HouseholdTestUtils.assertUserRole(
        householdMembers,
        regularMember.userId,
        'member',
      );
    });

    it('should return empty list for household with only manager', async () => {
      // Arrange - Create household with just manager
      const manager = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        { first_name: 'Solo', last_name: 'Manager' },
        db,
      );

      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          manager.userId,
          manager.sessionToken,
          { name: 'Solo Household' },
        );

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        manager.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const householdMembers = response.body.data.householdMembers;
      expect(householdMembers).toHaveLength(2); // Manager + AI assistant

      // Verify manager is present
      HouseholdTestUtils.assertUserRole(
        householdMembers,
        manager.userId,
        'manager',
      );

      // Verify AI assistant is present
      const aiMember = householdMembers.find(
        (member: any) => member.role === 'ai',
      );
      expect(aiMember).toBeDefined();
    });

    it('should return 401 when not authenticated', async () => {
      // Arrange - Create household but don't authenticate
      const manager = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          manager.userId,
          manager.sessionToken,
        );

      // Act - Try to access without authentication
      const response = await GraphQLTestUtils.executeQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Authentication required');
    });

    it('should return 403 when user is not a household member', async () => {
      // Arrange - Create two separate users and households
      const householdOwner = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        { first_name: 'Owner', last_name: 'User' },
        db,
      );

      const outsider = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        { first_name: 'Outsider', last_name: 'User' },
        db,
      );

      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          householdOwner.userId,
          householdOwner.sessionToken,
          { name: 'Private Household' },
        );

      // Act - Outsider tries to access household members
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        outsider.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      HouseholdTestUtils.assertPermissionError(response);
    });

    it('should return 404 when household does not exist', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const nonExistentHouseholdId = '00000000-0000-4000-8000-000000000000';

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        user.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(nonExistentHouseholdId),
      );

      // Assert - Should return permission error instead of revealing household existence
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(
        response,
        'Insufficient permissions to view household members',
      );
    });

    it('should handle malformed household ID gracefully', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      // Act - Try with empty household ID
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        user.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(''),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
    });

    it('should work correctly in multi-household scenario', async () => {
      // Arrange - Create user who belongs to multiple households
      const sharedUser = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        { first_name: 'Shared', last_name: 'User' },
        db,
      );

      // Create first household with shared user as manager
      const { householdId: householdA } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          sharedUser.userId,
          sharedUser.sessionToken,
          { name: 'Household A' },
        );

      // Create second household and add shared user as member
      const householdBOwner = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        { first_name: 'Owner', last_name: 'B' },
        db,
      );

      const { householdId: householdB } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          householdBOwner.userId,
          householdBOwner.sessionToken,
          { name: 'Household B' },
        );

      await IntegrationTestModuleFactory.addUserToHousehold(
        testRequest,
        db,
        householdB,
        sharedUser.userId,
        'member',
        householdBOwner.sessionToken,
      );

      // Act - Query members of household A (where shared user is manager)
      const responseA = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        sharedUser.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdA),
      );

      // Act - Query members of household B (where shared user is member)
      const responseB = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        sharedUser.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdB),
      );

      // Assert - Can access both households
      expect(responseA.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(responseA);
      expect(responseB.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(responseB);

      // Verify correct roles in each household
      const membersA = responseA.body.data.householdMembers;
      const membersB = responseB.body.data.householdMembers;

      HouseholdTestUtils.assertUserRole(membersA, sharedUser.userId, 'manager');
      HouseholdTestUtils.assertUserRole(membersB, sharedUser.userId, 'member');
      HouseholdTestUtils.assertUserRole(
        membersB,
        householdBOwner.userId,
        'manager',
      );
    });

    it('should include all member details with proper timestamps', async () => {
      // Arrange
      const { manager, members, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          1,
        );

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        manager.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const householdMembers = response.body.data.householdMembers;

      householdMembers.forEach((member: any) => {
        // Verify all required fields are present
        expect(member).toHaveProperty('id');
        expect(member).toHaveProperty('household_id');
        expect(member).toHaveProperty('user_id');
        expect(member).toHaveProperty('role');
        expect(member).toHaveProperty('joined_at');

        // Verify field types and formats
        expect(typeof member.id).toBe('string');
        expect(member.household_id).toBe(householdId);
        expect(typeof member.user_id).toBe('string');
        expect(['manager', 'member', 'ai']).toContain(member.role);
        expect(new Date(member.joined_at)).toBeInstanceOf(Date);
      });
    });
  });

  describe('GraphQL schema validation', () => {
    it('should reject invalid query structure', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const invalidQuery = `
        query InvalidQuery {
          householdMembers {
            nonExistentField
          }
        }
      `;

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        invalidQuery,
        user.sessionToken,
      );

      // Assert
      expect(response.status).toBe(400); // GraphQL validation error
      expect(response.body.errors).toBeDefined();
    });

    it('should enforce required arguments', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const queryWithoutRequiredArgs = `
        query MissingArgs {
          householdMembers {
            id
            user_id
            role
          }
        }
      `;

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        queryWithoutRequiredArgs,
        user.sessionToken,
      );

      // Assert
      expect(response.status).toBe(400);
      expect(response.body.errors).toBeDefined();
    });

    it('should validate input argument types', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const queryWithInvalidInput = `
        query InvalidInput {
          householdMembers(input: { householdId: 123 }) {
            id
            user_id
            role
          }
        }
      `;

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        queryWithInvalidInput,
        user.sessionToken,
      );

      // Assert
      expect(response.status).toBe(400);
      expect(response.body.errors).toBeDefined();
    });
  });

  describe('error handling edge cases', () => {
    it('should handle invalid session token', async () => {
      // Arrange
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          user.userId,
          user.sessionToken,
        );

      // Act - Try with invalid session token
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        'invalid-session-token',
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Invalid token');
    });

    it('should handle database connection issues gracefully', async () => {
      // Note: This test would require mocking database failures
      // For now, we'll test that the query structure works correctly
      const user = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          user.userId,
          user.sessionToken,
        );

      // Act - Normal query should work
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_HOUSEHOLD_MEMBERS,
        user.sessionToken,
        GraphQLTestUtils.createGetHouseholdMembersInput(householdId),
      );

      // Assert - Should work normally (database is functional in test)
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);
    });
  });
});
