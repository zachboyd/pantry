import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../../generated/database.js';
import { IntegrationTestModuleFactory } from '../../../../test/utils/integration-test-module-factory.js';
import { TestDatabaseService } from '../../../../test/utils/test-database.service.js';
import { GraphQLTestUtils } from '../../../../test/utils/graphql-test-utils.js';

describe('User Resolver Integration Tests', () => {
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

  describe('user query', () => {
    it('should return user when found and accessible', async () => {
      // Arrange - Sign up test user using real auth
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Integration',
            last_name: 'Test',
            display_name: 'Integration Test',
          },
          db,
        );

      // Act - Execute GraphQL query
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        sessionToken,
        GraphQLTestUtils.createGetUserInput(userId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.user;
      expect(userData).toMatchObject({
        id: userId,
        first_name: 'Integration',
        last_name: 'Test',
        display_name: 'Integration Test',
      });
      expect(userData.created_at).toBeDefined();
      expect(userData.updated_at).toBeDefined();
    });

    it('should allow user to view their own profile', async () => {
      // Arrange
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Self',
            last_name: 'Viewer',
            display_name: 'Self Viewer',
          },
          db,
        );

      // Act - User viewing their own profile
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        sessionToken,
        GraphQLTestUtils.createGetUserInput(userId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);
      expect(response.data.user.first_name).toBe('Self');
      expect(response.data.user.last_name).toBe('Viewer');
    });

    it('should return 401 when not authenticated', async () => {
      // Arrange - Sign up a user but use their ID without authentication
      const { userId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'Unauthorized',
          last_name: 'User',
        },
        db,
      );

      // Act - Try to access user without authentication
      const response = await GraphQLTestUtils.executeQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        GraphQLTestUtils.createGetUserInput(userId),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Authentication required');
    });

    it('should return 403 when user not found (security: no information leakage)', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);
      const nonExistentUserId = '00000000-0000-4000-8000-000000000000'; // Valid UUID format

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        sessionToken,
        GraphQLTestUtils.createGetUserInput(nonExistentUserId),
      );

      // Assert - Should return permission error, not "not found" to avoid information leakage
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'permission');
    });

    it('should return 403 when user lacks permission to view other user', async () => {
      // Arrange - Create two users
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Viewer',
            last_name: 'User',
          },
          db,
        );

      const { userId: otherUserId } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Other',
            last_name: 'User',
          },
          db,
        );

      // Act - Try to view other user without permission
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        sessionToken,
        GraphQLTestUtils.createGetUserInput(otherUserId),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'permission');
    });

    it('should handle malformed user ID gracefully', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);

      // Act - Try with empty user ID
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_USER,
        sessionToken,
        GraphQLTestUtils.createGetUserInput(''),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
    });
  });

  describe('currentUser query', () => {
    it('should return current authenticated user', async () => {
      // Arrange
      const { userId, sessionToken, email } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Current',
            last_name: 'User',
          },
          db,
        );

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.currentUser;
      expect(userData).toMatchObject({
        id: userId,
        first_name: 'Current',
        last_name: 'User',
        email: email,
        display_name: 'Current User',
      });
      expect(userData.created_at).toBeDefined();
      expect(userData.updated_at).toBeDefined();
    });

    it('should return fresh user data from database', async () => {
      // Arrange - Create user and get session
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Original',
            last_name: 'Name',
          },
          db,
        );

      // Update user in database directly (simulating external update)
      await db
        .updateTable('user')
        .set({
          first_name: 'Updated',
          last_name: 'Name',
          updated_at: new Date(),
        })
        .where('id', '=', userId)
        .execute();

      // Act - Get current user should return updated data
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);
      expect(response.data.currentUser.first_name).toBe('Updated');
    });

    it('should return 401 when not authenticated', async () => {
      // Act - Try to get current user without authentication
      const response = await GraphQLTestUtils.executeQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Authentication required');
    });

    it('should return 404 when authenticated user not found in database', async () => {
      // Arrange - Create session but remove user from database
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);

      // Remove user from database (orphaned session)
      await db.deleteFrom('user').where('id', '=', userId).execute();

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Current user not found');
    });

    it('should handle invalid session token', async () => {
      // Act - Try with invalid session token
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        'invalid-session-token',
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Invalid token');
    });

    it('should handle expired session token', async () => {
      // Arrange - Create user but create expired session manually
      const { authUserId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {},
        db,
      );

      // Create expired session
      const expiredSessionToken = 'expired-session-' + Date.now();
      await db
        .insertInto('auth_session')
        .values({
          id: 'expired-session-' + Date.now(),
          userId: authUserId,
          token: expiredSessionToken,
          expiresAt: new Date(Date.now() - 1000), // Expired 1 second ago
          createdAt: new Date(),
          updatedAt: new Date(),
        })
        .execute();

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        expiredSessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Invalid token');
    });
  });

  describe('GraphQL schema validation', () => {
    it('should reject invalid query structure', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);
      const invalidQuery = `
        query InvalidQuery {
          user {
            nonExistentField
          }
        }
      `;

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        invalidQuery,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(400); // GraphQL validation error
      expect(response.body.errors).toBeDefined();
    });

    it('should enforce required arguments', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);
      const queryWithoutRequiredArgs = `
        query MissingArgs {
          user {
            id
            first_name
          }
        }
      `;

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        queryWithoutRequiredArgs,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(400);
      expect(response.body.errors).toBeDefined();
    });
  });

  describe('updateUser mutation', () => {
    it('should update own profile successfully', async () => {
      // Arrange - Sign up test user
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Original',
            last_name: 'Name',
            display_name: 'Original Display',
          },
          db,
        );

      // Act - Update user profile
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          first_name: 'Updated',
          last_name: 'NewName',
          display_name: 'Updated Display Name',
          phone: '+1234567890',
        }),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.updateUser;
      expect(userData).toMatchObject({
        id: userId,
        first_name: 'Updated',
        last_name: 'NewName',
        display_name: 'Updated Display Name',
        phone: '+1234567890',
      });
      expect(userData.created_at).toBeDefined();
      expect(userData.updated_at).toBeDefined();
    });

    it('should update only provided fields', async () => {
      // Arrange - Sign up test user with simple names to avoid auth sync issues
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Original',
            last_name: 'User',
          },
          db,
        );

      // First, update user with initial values to establish known state
      const setupResponse = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          display_name: 'Original Display',
          phone: '+0000000000',
        }),
      );
      expect(setupResponse.status).toBe(200);

      // Act - Update only first name
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          first_name: 'UpdatedFirst',
        }),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.updateUser;
      expect(userData).toMatchObject({
        id: userId,
        first_name: 'UpdatedFirst',
        last_name: 'User', // unchanged
        display_name: 'Original Display', // unchanged
        phone: '+0000000000', // unchanged
      });
    });

    it('should return 401 when not authenticated', async () => {
      // Arrange - Sign up a user but use their ID without authentication
      const { userId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'Unauthorized',
          last_name: 'User',
        },
        db,
      );

      // Act - Try to update user without authentication
      const response = await GraphQLTestUtils.executeQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          first_name: 'Hacked',
        }),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(response, 'Authentication required');
    });

    it('should return 404 when user not found', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);
      const nonExistentUserId = '00000000-0000-4000-8000-000000000000'; // Valid UUID format

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(nonExistentUserId, {
          first_name: 'DoesNotExist',
        }),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(
        response,
        'User with ID 00000000-0000-4000-8000-000000000000 not found',
      );
    });

    it('should return 403 when trying to update other user without permission', async () => {
      // Arrange - Create two separate users
      const { sessionToken: user1Token } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'User',
            last_name: 'One',
          },
          db,
        );

      const { userId: user2Id } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'User',
            last_name: 'Two',
          },
          db,
        );

      // Act - User 1 tries to update User 2's profile
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        user1Token,
        GraphQLTestUtils.createUpdateUserInput(user2Id, {
          first_name: 'Hacked',
        }),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(
        response,
        'You do not have permission to update this user',
      );
    });

    it('should handle all supported update fields', async () => {
      // Arrange - Sign up test user
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Original',
            last_name: 'Name',
          },
          db,
        );

      // Act - Update all supported fields
      const updateData = {
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Updated Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        birth_date: new Date('1990-01-01'),
        email: 'updated@example.com',
      };

      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, updateData),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.updateUser;
      expect(userData).toMatchObject({
        id: userId,
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Updated Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        email: 'updated@example.com',
      });
      // Note: birth_date comparison might need special handling due to date serialization
      expect(userData.birth_date).toBeDefined();
    });

    it('should allow household manager to update AI user in their household', async () => {
      // Arrange - Create household with manager and AI user
      const { manager, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0, // No additional members, just manager and AI
        );

      // Find the AI user in the household
      const aiUser = await db
        .selectFrom('household_member')
        .innerJoin('user', 'user.id', 'household_member.user_id')
        .selectAll('user')
        .where('household_member.household_id', '=', householdId)
        .where('household_member.role', '=', 'ai')
        .executeTakeFirst();

      expect(aiUser).toBeDefined();

      // Act - Manager updates AI user profile
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        manager.sessionToken,
        GraphQLTestUtils.createUpdateUserInput(aiUser!.id, {
          first_name: 'Assistant',
          last_name: 'AI',
          display_name: 'Household AI Assistant',
        }),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.updateUser;
      expect(userData).toMatchObject({
        id: aiUser!.id,
        first_name: 'Assistant',
        last_name: 'AI',
        display_name: 'Household AI Assistant',
      });
    });

    it('should forbid household member from updating AI user', async () => {
      // Arrange - Create household with manager, member, and AI user
      const { manager, members, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          1, // Create 1 member
        );

      const member = members[0];

      // Find the AI user in the household
      const aiUser = await db
        .selectFrom('household_member')
        .innerJoin('user', 'user.id', 'household_member.user_id')
        .selectAll('user')
        .where('household_member.household_id', '=', householdId)
        .where('household_member.role', '=', 'ai')
        .executeTakeFirst();

      expect(aiUser).toBeDefined();

      // Act - Member tries to update AI user profile
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        member.sessionToken,
        GraphQLTestUtils.createUpdateUserInput(aiUser!.id, {
          first_name: 'Hacked',
          display_name: 'Compromised AI',
        }),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(
        response,
        'You do not have permission to update this user',
      );
    });

    it('should forbid user from updating AI user in different household', async () => {
      // Arrange - Create two separate households
      const { manager: manager1, householdId: household1Id } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      const { manager: manager2, householdId: household2Id } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      // Find the AI user in household2
      const aiUserHousehold2 = await db
        .selectFrom('household_member')
        .innerJoin('user', 'user.id', 'household_member.user_id')
        .selectAll('user')
        .where('household_member.household_id', '=', household2Id)
        .where('household_member.role', '=', 'ai')
        .executeTakeFirst();

      expect(aiUserHousehold2).toBeDefined();

      // Act - Manager1 tries to update AI user from household2
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        manager1.sessionToken,
        GraphQLTestUtils.createUpdateUserInput(aiUserHousehold2!.id, {
          first_name: 'Unauthorized',
          display_name: 'Cross-household hack',
        }),
      );

      // Assert
      expect(response.status).toBe(200); // GraphQL always returns 200
      GraphQLTestUtils.assertHasErrors(response);
      GraphQLTestUtils.assertErrorMessage(
        response,
        'You do not have permission to update this user',
      );
    });

    it('should verify AI user has expected properties after manager update', async () => {
      // Arrange - Create household with AI user
      const { manager, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      // Find the AI user
      const aiUser = await db
        .selectFrom('household_member')
        .innerJoin('user', 'user.id', 'household_member.user_id')
        .selectAll('user')
        .where('household_member.household_id', '=', householdId)
        .where('household_member.role', '=', 'ai')
        .executeTakeFirst();

      expect(aiUser).toBeDefined();
      expect(aiUser!.is_ai).toBe(true); // Verify it's marked as AI user

      // Act - Update AI user with comprehensive data
      const updateData = {
        first_name: 'Advanced',
        last_name: 'Assistant',
        display_name: 'Household AI Helper',
        avatar_url: 'https://example.com/ai-avatar.jpg',
      };

      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        manager.sessionToken,
        GraphQLTestUtils.createUpdateUserInput(aiUser!.id, updateData),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.data.updateUser;
      expect(userData).toMatchObject({
        id: aiUser!.id,
        first_name: 'Advanced',
        last_name: 'Assistant',
        display_name: 'Household AI Helper',
        avatar_url: 'https://example.com/ai-avatar.jpg',
      });

      // Verify AI user properties remain intact in database
      const updatedAiUser = await db
        .selectFrom('user')
        .selectAll()
        .where('id', '=', aiUser!.id)
        .executeTakeFirst();

      expect(updatedAiUser!.is_ai).toBe(true);
      expect(updatedAiUser!.first_name).toBe('Advanced');
      expect(updatedAiUser!.display_name).toBe('Household AI Helper');
    });
  });

  describe('currentUser query with primary_household_id', () => {
    it('should return null primary_household_id for new user without household', async () => {
      // Arrange - Create user without any household
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.body.data.currentUser;
      expect(userData).toMatchObject({
        id: userId,
        primary_household_id: null,
      });
    });

    it('should return primary_household_id when user creates their first household', async () => {
      // Arrange - Create user
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);

      // Create household (should become primary)
      const { householdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          userId,
          sessionToken,
        );

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.body.data.currentUser;
      expect(userData).toMatchObject({
        id: userId,
        primary_household_id: householdId,
      });
    });

    it('should maintain correct primary_household_id when user has multiple households', async () => {
      // Arrange - Create user with first household
      const { manager, householdId: firstHouseholdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      // Create second household (should not change primary)
      const { householdId: secondHouseholdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          manager.userId,
          manager.sessionToken,
        );

      // Act
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.QUERIES.GET_CURRENT_USER,
        manager.sessionToken,
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.body.data.currentUser;
      expect(userData.primary_household_id).toBe(firstHouseholdId);
      expect(userData.primary_household_id).not.toBe(secondHouseholdId);
    });

    it('should allow updating primary_household_id via updateUser mutation', async () => {
      // Arrange - Create user with household
      const { manager, householdId: firstHouseholdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      // Create second household
      const { householdId: secondHouseholdId } =
        await IntegrationTestModuleFactory.createTestHousehold(
          testRequest,
          db,
          manager.userId,
          manager.sessionToken,
        );

      // Act - Update primary household to the second one
      const response = await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        manager.sessionToken,
        GraphQLTestUtils.createUpdateUserInput(manager.userId, {
          primary_household_id: secondHouseholdId,
        }),
      );

      // Assert
      expect(response.status).toBe(200);
      GraphQLTestUtils.assertNoErrors(response);

      const userData = response.body.data.updateUser;
      expect(userData.primary_household_id).toBe(secondHouseholdId);
      expect(userData.primary_household_id).not.toBe(firstHouseholdId);
    });
  });
});
