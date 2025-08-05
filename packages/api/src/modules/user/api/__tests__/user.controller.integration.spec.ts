import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../../generated/database.js';
import { IntegrationTestModuleFactory } from '../../../../test/utils/integration-test-module-factory.js';
import { TestDatabaseService } from '../../../../test/utils/test-database.service.js';

describe('User Controller Integration Tests', () => {
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

  describe('GET /api/user/current', () => {
    it('should return current authenticated user', async () => {
      // Arrange - Sign up test user
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Current',
            last_name: 'User',
            display_name: 'Current User',
          },
          db,
        );

      // Act
      const response = await testRequest
        .get('/api/user/current')
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'Current',
        last_name: 'User',
        display_name: 'Current User',
      });
      expect(response.body.created_at).toBeDefined();
      expect(response.body.updated_at).toBeDefined();
    });

    it('should return 401 when not authenticated', async () => {
      // Act & Assert
      await testRequest
        .get('/api/user/current')
        .expect(401);
    });
  });

  describe('GET /api/user/:id', () => {
    it('should return user when accessing own profile', async () => {
      // Arrange
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Target',
            last_name: 'User',
          },
          db,
        );

      // Act
      const response = await testRequest
        .get(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'Target',
        last_name: 'User',
      });
    });

    it('should return 401 when not authenticated', async () => {
      // Arrange - Sign up a user but access without authentication
      const { userId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'Unauthorized',
          last_name: 'User',
        },
        db,
      );

      // Act & Assert
      await testRequest
        .get(`/api/user/${userId}`)
        .expect(401);
    });
  });

  describe('PUT /api/user/:id', () => {
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

      const updateData = {
        first_name: 'Updated',
        last_name: 'NewName',
        display_name: 'Updated Display Name',
        phone: '+1234567890',
      };

      // Act
      const response = await testRequest
        .put(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send(updateData)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'Updated',
        last_name: 'NewName',
        display_name: 'Updated Display Name',
        phone: '+1234567890',
      });
      expect(response.body.created_at).toBeDefined();
      expect(response.body.updated_at).toBeDefined();
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
      await testRequest
        .put(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send({
          display_name: 'Original Display',
          phone: '+0000000000',
        })
        .expect(200);

      // Act - Update only first name
      const response = await testRequest
        .put(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send({
          first_name: 'UpdatedFirst',
        })
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'UpdatedFirst',
        last_name: 'User', // unchanged
        display_name: 'Original Display', // unchanged
        phone: '+0000000000', // unchanged
      });
    });

    it('should return 401 when not authenticated', async () => {
      // Arrange - Sign up a user but update without authentication
      const { userId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'Unauthorized',
          last_name: 'User',
        },
        db,
      );

      // Act & Assert
      await testRequest
        .put(`/api/user/${userId}`)
        .send({
          first_name: 'Hacked',
        })
        .expect(401);
    });

    it('should return 404 when user not found', async () => {
      // Arrange
      const { sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);
      const nonExistentUserId = '00000000-0000-4000-8000-000000000000'; // Valid UUID format

      // Act & Assert
      await testRequest
        .put(`/api/user/${nonExistentUserId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send({
          first_name: 'DoesNotExist',
        })
        .expect(404);
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

      const { userId: user2Id } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'User',
          last_name: 'Two',
        },
        db,
      );

      // Act & Assert - User1 tries to update User2 (who they don't manage)
      await testRequest
        .put(`/api/user/${user2Id}`)
        .set('Cookie', `pantry.session_token=${user1Token}`)
        .send({
          first_name: 'Hacked',
        })
        .expect(403);
    });

    it('should allow manager to update managed user', async () => {
      // Arrange - Create manager and managed user
      const { userId: managerId, sessionToken: managerToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Manager',
            last_name: 'User',
          },
          db,
        );

      const { userId: managedUserId } = await IntegrationTestModuleFactory.signUpTestUser(
        testRequest,
        {
          first_name: 'Managed',
          last_name: 'User',
        },
        db,
      );

      // Set up managed_by relationship in the database
      await db
        .updateTable('user')
        .set({ managed_by: managerId })
        .where('id', '=', managedUserId)
        .execute();

      // Act - Manager updates managed user's profile
      const response = await testRequest
        .put(`/api/user/${managedUserId}`)
        .set('Cookie', `pantry.session_token=${managerToken}`)
        .send({
          first_name: 'UpdatedByManager',
          display_name: 'Managed User',
        })
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: managedUserId,
        first_name: 'UpdatedByManager',
        display_name: 'Managed User',
      });
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
        birth_date: '1990-01-01T00:00:00.000Z',
        email: 'updated@example.com',
      };

      const response = await testRequest
        .put(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send(updateData)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'Updated',
        last_name: 'LastName',
        display_name: 'Updated Display Name',
        avatar_url: 'https://example.com/avatar.jpg',
        phone: '+1234567890',
        email: 'updated@example.com',
      });
      // Note: birth_date comparison might need special handling due to date serialization
      expect(response.body.birth_date).toBeDefined();
    });

    it('should handle empty body gracefully', async () => {
      // Arrange
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(
          testRequest,
          {
            first_name: 'Original',
            last_name: 'User',
          },
          db,
        );

      // Act - Send empty update
      const response = await testRequest
        .put(`/api/user/${userId}`)
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .send({})
        .expect(200);

      // Assert - User should remain unchanged
      expect(response.body).toMatchObject({
        id: userId,
        first_name: 'Original',
        last_name: 'User',
      });
    });
  });

  describe('GET /api/user/current with primary_household_id', () => {
    it('should return null primary_household_id for new user without household', async () => {
      // Arrange - Create user without any household
      const { userId, sessionToken } =
        await IntegrationTestModuleFactory.signUpTestUser(testRequest, {}, db);

      // Act
      const response = await testRequest
        .get('/api/user/current')
        .set('Cookie', `pantry.session_token=${sessionToken}`)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: userId,
        primary_household_id: null,
      });
    });

    it('should return primary_household_id when user creates their first household', async () => {
      // Arrange - Create user with household
      const { manager, householdId } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0, // No additional members
        );

      // Act
      const response = await testRequest
        .get('/api/user/current')
        .set('Cookie', `pantry.session_token=${manager.sessionToken}`)
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: manager.userId,
        primary_household_id: householdId,
      });
    });

    it('should return 401 when not authenticated', async () => {
      // Act & Assert
      await testRequest
        .get('/api/user/current')
        .expect(401);
    });
  });

  describe('PUT /api/user/:id with primary_household_id', () => {
    it('should update primary_household_id successfully', async () => {
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

      // Act - Update primary household via REST API
      const response = await testRequest
        .put(`/api/user/${manager.userId}`)
        .set('Cookie', `pantry.session_token=${manager.sessionToken}`)
        .send({
          primary_household_id: secondHouseholdId,
        })
        .expect(200);

      // Assert
      expect(response.body.primary_household_id).toBe(secondHouseholdId);
      expect(response.body.primary_household_id).not.toBe(firstHouseholdId);
    });

    it('should update primary_household_id along with other fields', async () => {
      // Arrange - Create user with household
      const { manager } =
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

      // Act - Update primary household and other fields via REST API
      const response = await testRequest
        .put(`/api/user/${manager.userId}`)
        .set('Cookie', `pantry.session_token=${manager.sessionToken}`)
        .send({
          primary_household_id: secondHouseholdId,
          first_name: 'Updated',
          last_name: 'Name',
        })
        .expect(200);

      // Assert
      expect(response.body).toMatchObject({
        id: manager.userId,
        primary_household_id: secondHouseholdId,
        first_name: 'Updated',
        last_name: 'Name',
      });
    });

    it('should allow setting primary_household_id to null', async () => {
      // Arrange - Create user with household
      const { manager } =
        await IntegrationTestModuleFactory.createHouseholdWithMembers(
          testRequest,
          db,
          0,
        );

      // Act - Set primary household to null
      const response = await testRequest
        .put(`/api/user/${manager.userId}`)
        .set('Cookie', `pantry.session_token=${manager.sessionToken}`)
        .send({
          primary_household_id: null,
        })
        .expect(200);

      // Assert
      expect(response.body.primary_household_id).toBe(null);
    });
  });
});