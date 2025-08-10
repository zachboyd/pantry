import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
  afterEach,
} from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../../generated/database.js';
import { IntegrationTestModuleFactory } from '../../../../test/utils/integration-test-module-factory.js';
import { TestDatabaseService } from '../../../../test/utils/test-database.service.js';
import { GraphQLTestUtils } from '../../../../test/utils/graphql-test-utils.js';
import { GraphQLWebSocketTestUtils } from '../../../../test/utils/graphql-websocket-test-utils.js';

describe('User Subscription Integration Tests', () => {
  let app: INestApplication;
  let testRequest: ReturnType<typeof import('supertest')>;
  let db: Kysely<DB>;
  let testDbService: TestDatabaseService;
  let wsUrl: string;

  beforeAll(async () => {
    // Create integration test app once for all tests
    const testApp = await IntegrationTestModuleFactory.createApp();
    app = testApp.app;
    testRequest = testApp.request;
    db = testApp.db;
    testDbService = testApp.testDbService;

    // Start the server on a random port for WebSocket support
    await app.listen(0); // Listen on random available port
    const address = app.getHttpServer().address();
    const port = typeof address === 'string' ? 3001 : address?.port || 3001;
    wsUrl = `ws://localhost:${port}/graphql`;

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

  afterEach(async () => {
    // Clean up WebSocket clients after each test
    await GraphQLWebSocketTestUtils.cleanup();
  });

  afterAll(async () => {
    // Clean database after all tests to avoid interfering with other test files
    try {
      await IntegrationTestModuleFactory.cleanDatabase(db);
    } catch (error) {
      console.warn('Database cleanup skipped in afterAll:', error);
    }

    // Final cleanup
    await GraphQLWebSocketTestUtils.cleanup();
    await IntegrationTestModuleFactory.closeApp(app, testDbService);
  });

  describe('userUpdated subscription', () => {
    it('should receive user updates when user profile is modified', async () => {
      // Arrange - Create test user and establish subscription
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Subscription',
            last_name: 'Test',
            display_name: 'Original Name',
          },
          db,
        );

      const client = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken,
      });

      // Start subscription
      const subscriptionPromise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            id: string;
            display_name?: string;
            phone?: string;
            first_name: string;
            last_name: string;
            created_at: string;
            updated_at: string;
            [key: string]: unknown;
          };
        }>({
          client,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 10000,
        });

      // Act - Update user profile via GraphQL mutation
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          display_name: 'Updated via Subscription',
          phone: '+1234567890',
        }),
      );

      // Assert - Verify subscription received the update
      const result = await subscriptionPromise;

      GraphQLWebSocketTestUtils.assertNoErrors(result);
      GraphQLWebSocketTestUtils.assertMessageCount(result, 1);
      GraphQLWebSocketTestUtils.assertCompleted(result);

      const userUpdate = result.results[0].userUpdated;
      expect(userUpdate).toMatchObject({
        id: userId,
        display_name: 'Updated via Subscription',
        phone: '+1234567890',
      });

      // Verify that first_name and last_name are present (they come from auth system)
      expect(userUpdate.first_name).toBeDefined();
      expect(userUpdate.last_name).toBeDefined();

      // Verify DateTime fields are properly serialized
      expect(userUpdate.created_at).toBeDefined();
      expect(userUpdate.updated_at).toBeDefined();
      expect(typeof userUpdate.created_at).toBe('string');
      expect(typeof userUpdate.updated_at).toBe('string');

      // Verify DateTime format is valid ISO string
      expect(() => new Date(userUpdate.created_at)).not.toThrow();
      expect(() => new Date(userUpdate.updated_at)).not.toThrow();
    });

    it('should only receive updates for the authenticated user (security)', async () => {
      // Arrange - Create two separate users
      const { userId: user1Id, sessionToken: user1Token } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'User',
            last_name: 'One',
          },
          db,
        );

      const { userId: user2Id, sessionToken: user2Token } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'User',
            last_name: 'Two',
          },
          db,
        );

      // User1 subscribes to their own updates
      const user1Client = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken: user1Token,
      });

      const user1SubscriptionPromise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            id: string;
            display_name: string;
            [key: string]: unknown;
          };
        }>({
          client: user1Client,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 5000,
        });

      // Act - Update User2's profile (User1 should not receive this)
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        user2Token,
        GraphQLTestUtils.createUpdateUserInput(user2Id, {
          display_name: 'User Two Updated',
        }),
      );

      // Update User1's profile (User1 should receive this)
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        user1Token,
        GraphQLTestUtils.createUpdateUserInput(user1Id, {
          display_name: 'User One Updated',
        }),
      );

      // Assert - User1 should only receive their own update
      const result = await user1SubscriptionPromise;

      GraphQLWebSocketTestUtils.assertNoErrors(result);
      GraphQLWebSocketTestUtils.assertMessageCount(result, 1);
      GraphQLWebSocketTestUtils.assertCompleted(result);

      const userUpdate = result.results[0].userUpdated;
      expect(userUpdate.id).toBe(user1Id);
      expect(userUpdate.display_name).toBe('User One Updated');
    });

    it('should reject unauthenticated subscription attempts', async () => {
      // Arrange - Create client without authentication
      const client = GraphQLWebSocketTestUtils.createClient({
        url: wsUrl,
      });

      // Act & Assert - Try to subscribe without authentication
      const result = await GraphQLWebSocketTestUtils.executeSubscription({
        client,
        query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
        expectedMessages: 0,
        timeout: 3000,
      });

      // Should receive an error
      GraphQLWebSocketTestUtils.assertHasErrors(result);
      expect((result.errors[0] as { message: string }).message).toContain(
        'Authentication required',
      );
    });

    it('should reject subscription with invalid session token', async () => {
      // Arrange - Create client with invalid token
      const client = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken: 'invalid-token-12345',
      });

      // Act & Assert - Try to subscribe with invalid token
      const result = await GraphQLWebSocketTestUtils.executeSubscription({
        client,
        query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
        expectedMessages: 0,
        timeout: 3000,
      });

      // Should receive an error
      GraphQLWebSocketTestUtils.assertHasErrors(result);
      expect((result.errors[0] as { message: string }).message).toContain(
        'Invalid token',
      );
    });

    it('should handle multiple subscription clients for the same user', async () => {
      // Arrange - Create user and multiple subscription clients
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Multi',
            last_name: 'Client',
          },
          db,
        );

      const client1 = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken,
      });

      const client2 = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken,
      });

      // Wait for both clients to establish connections
      await Promise.all([
        GraphQLWebSocketTestUtils.waitForConnection(client1, 10000),
        GraphQLWebSocketTestUtils.waitForConnection(client2, 10000),
      ]);

      // Small delay to ensure connection stability
      await new Promise((resolve) => setTimeout(resolve, 100));

      // Start subscriptions on both clients
      const subscription1Promise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            display_name: string;
            [key: string]: unknown;
          };
        }>({
          client: client1,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 12000, // Increased timeout for multiple clients
        });

      const subscription2Promise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            display_name: string;
            [key: string]: unknown;
          };
        }>({
          client: client2,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 12000, // Increased timeout for multiple clients
        });

      // Small delay to ensure subscriptions are established
      await new Promise((resolve) => setTimeout(resolve, 200));

      // Act - Update user profile
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          display_name: 'Multi Client Updated',
        }),
      );

      // Assert - Both clients should receive the update
      const [result1, result2] = await Promise.all([
        subscription1Promise,
        subscription2Promise,
      ]);

      GraphQLWebSocketTestUtils.assertNoErrors(result1);
      GraphQLWebSocketTestUtils.assertMessageCount(result1, 1);
      GraphQLWebSocketTestUtils.assertCompleted(result1);

      GraphQLWebSocketTestUtils.assertNoErrors(result2);
      GraphQLWebSocketTestUtils.assertMessageCount(result2, 1);
      GraphQLWebSocketTestUtils.assertCompleted(result2);

      expect(result1.results[0].userUpdated.display_name).toBe(
        'Multi Client Updated',
      );
      expect(result2.results[0].userUpdated.display_name).toBe(
        'Multi Client Updated',
      );
    });

    it('should properly serialize all user fields including dates and JSON', async () => {
      // Arrange - Create user with comprehensive profile
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Complex',
            last_name: 'Profile',
          },
          db,
        );

      const client = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken,
      });

      const subscriptionPromise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            id: string;
            first_name: string;
            last_name: string;
            display_name: string;
            avatar_url: string;
            phone: string;
            email: string;
            is_ai: boolean;
            created_at: string;
            updated_at: string;
            birth_date: string;
            preferences: unknown;
            [key: string]: unknown;
          };
        }>({
          client,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 8000,
        });

      // Act - Update with all supported field types
      const birthDate = new Date('1990-06-15');
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          first_name: 'Updated',
          last_name: 'Complex',
          display_name: 'Complex Updated Profile',
          avatar_url: 'https://example.com/avatar.jpg',
          phone: '+1-555-0123',
          birth_date: birthDate,
          email: 'complex@example.com',
          preferences: {
            theme: 'dark',
            notifications: {
              email: true,
              push: false,
            },
            language: 'en',
          },
        }),
      );

      // Assert - Verify all field types are properly serialized
      const result = await subscriptionPromise;

      GraphQLWebSocketTestUtils.assertNoErrors(result);
      GraphQLWebSocketTestUtils.assertMessageCount(result, 1);

      const userUpdate = result.results[0].userUpdated;
      expect(userUpdate).toMatchObject({
        id: userId,
        first_name: 'Updated',
        last_name: 'Complex',
        display_name: 'Complex Updated Profile',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1-555-0123',
        email: 'complex@example.com',
        is_ai: false,
      });

      // Verify DateTime fields
      expect(userUpdate.created_at).toBeDefined();
      expect(userUpdate.updated_at).toBeDefined();
      expect(userUpdate.birth_date).toBeDefined();
      expect(typeof userUpdate.created_at).toBe('string');
      expect(typeof userUpdate.updated_at).toBe('string');
      expect(typeof userUpdate.birth_date).toBe('string');

      // Verify DateTime values are valid
      expect(new Date(userUpdate.created_at).getTime()).not.toBeNaN();
      expect(new Date(userUpdate.updated_at).getTime()).not.toBeNaN();
      expect(new Date(userUpdate.birth_date).getTime()).not.toBeNaN();

      // Verify JSON fields
      expect(userUpdate.preferences).toEqual({
        theme: 'dark',
        notifications: {
          email: true,
          push: false,
        },
        language: 'en',
      });
    });

    it('should handle null and optional fields correctly', async () => {
      // Arrange - Create user with minimal profile
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Minimal',
            last_name: 'User',
          },
          db,
        );

      const client = GraphQLWebSocketTestUtils.createAuthenticatedClient({
        url: wsUrl,
        sessionToken,
      });

      const subscriptionPromise =
        GraphQLWebSocketTestUtils.executeSubscription<{
          userUpdated: {
            id: string;
            display_name: string;
            birth_date: string | null;
            avatar_url: string | null;
            phone: string | null;
            created_at: string;
            updated_at: string;
            [key: string]: unknown;
          };
        }>({
          client,
          query: GraphQLWebSocketTestUtils.SUBSCRIPTIONS.USER_UPDATED,
          expectedMessages: 1,
          timeout: 8000,
        });

      // Act - Update with some null/empty values
      await GraphQLTestUtils.executeAuthenticatedQuery(
        testRequest,
        GraphQLTestUtils.MUTATIONS.UPDATE_USER,
        sessionToken,
        GraphQLTestUtils.createUpdateUserInput(userId, {
          display_name: 'Updated Minimal',
          // avatar_url: null, // Not provided
          // phone: null, // Not provided
          // birth_date: null, // Not provided
        }),
      );

      // Assert - Verify null fields are handled correctly
      const result = await subscriptionPromise;

      GraphQLWebSocketTestUtils.assertNoErrors(result);
      GraphQLWebSocketTestUtils.assertMessageCount(result, 1);

      const userUpdate = result.results[0].userUpdated;
      expect(userUpdate.id).toBe(userId);
      expect(userUpdate.display_name).toBe('Updated Minimal');

      // These fields should be null or undefined and not cause serialization errors
      expect(userUpdate.birth_date).toBeNull();
      expect(userUpdate.avatar_url).toBeNull();
      expect(userUpdate.phone).toBeNull();

      // Required DateTime fields should still be present
      expect(userUpdate.created_at).toBeDefined();
      expect(userUpdate.updated_at).toBeDefined();
    });
  });
});
