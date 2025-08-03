import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import {
  NestExpressApplication,
  ExpressAdapter,
} from '@nestjs/platform-express';
import request from 'supertest';
import { randomUUID } from 'crypto';
import { toNodeHandler } from 'better-auth/node';
import express from 'express';
import { AppModule } from '../../app.module.js';
import { TOKENS } from '../../common/tokens.js';
import { TestDatabaseService } from './test-database.service.js';
import type { Kysely } from 'kysely';
import type { DB } from '../../generated/database.js';
import type { AuthFactory } from '../../modules/auth/auth.factory.js';

/**
 * Factory for creating full NestJS application instances for integration testing
 * Provides a real application context with database and GraphQL endpoints
 */
export class IntegrationTestModuleFactory {
  /**
   * Creates a full NestJS application for integration testing
   * Includes all modules, guards, and GraphQL endpoints
   */
  static async createApp(): Promise<{
    app: INestApplication;
    request: request.SuperTest<request.Test>;
    db: Kysely<DB>;
    testDbService: TestDatabaseService;
  }> {
    // Create test database service instance
    const testDbService = new TestDatabaseService();

    // Create Express instance (same as main.ts)
    const server = express();

    // Use the full AppModule and just override the database service
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      // Override database service with our test one
      .overrideProvider(TOKENS.DATABASE.SERVICE)
      .useValue(testDbService)
      .overrideProvider(TOKENS.DATABASE.CONNECTION)
      .useFactory(() => testDbService.getConnection())
      .compile();

    // Create NestJS app with Express adapter (same as main.ts)
    const app = await moduleRef.createNestApplication<NestExpressApplication>(
      new ExpressAdapter(server),
      {
        bodyParser: false,
      },
    );

    // Get AuthFactory to mount better-auth routes
    const authFactory = app.get<AuthFactory>(TOKENS.AUTH.FACTORY);

    // Mount better-auth handler (same as main.ts)
    server.all('/api/auth/*', toNodeHandler(authFactory.createAuthInstance()));
    server.use(express.json());

    // Configure the app (same as main.ts)
    app.enableCors();

    // Run test migrations before initializing the app
    await testDbService.runTestMigrations();

    // Initialize the application
    await app.init();

    // Get database connection for test setup/teardown
    const db = testDbService.getConnection();

    // Create supertest request instance
    const testRequest = request(app.getHttpServer());

    return {
      app,
      request: testRequest,
      db,
      testDbService,
    };
  }

  /**
   * Properly cleanup the integration test application
   */
  static async closeApp(
    app: INestApplication,
    testDbService?: TestDatabaseService,
  ): Promise<void> {
    if (testDbService) {
      await testDbService.close();
    }
    if (app) {
      await app.close();
    }
  }

  /**
   * Clean database tables for test isolation
   * Truncates all tables to ensure clean state between tests
   */
  static async cleanDatabase(db: Kysely<DB>): Promise<void> {
    // Order matters - delete dependent tables first
    const tables = [
      'typing_indicator',
      'message',
      'household_member',
      'household',
      'user',
      'auth_session',
      'auth_account',
      'auth_user',
      'auth_verification',
    ];

    for (const table of tables) {
      try {
        await db.deleteFrom(table as any).execute();
      } catch (error) {
        // Table might not exist in test database, continue
        console.warn(`Failed to clean table ${table}:`, error);
      }
    }
  }

  /**
   * Helper to execute GraphQL queries via HTTP
   */
  static async executeGraphQL(
    request: request.SuperTest<request.Test>,
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

    return response;
  }

  /**
   * Helper to sign up a test user using real better-auth API
   */
  static async signUpTestUser(
    request: request.SuperTest<request.Test>,
    userOverrides: Record<string, unknown> = {},
    db?: Kysely<DB>,
  ): Promise<{
    userId: string;
    authUserId: string;
    sessionToken: string;
    email: string;
  }> {
    const email =
      (userOverrides.email as string) || `test${Date.now()}@example.com`;
    const password = 'testPassword123!';
    const name =
      (userOverrides.display_name as string) ||
      `${userOverrides.first_name || 'Test'} ${userOverrides.last_name || 'User'}`;

    // Sign up via better-auth API
    const signUpResponse = await request.post('/api/auth/sign-up/email').send({
      email,
      password,
      name,
    });

    if (signUpResponse.status !== 200) {
      throw new Error(
        `User signup failed: ${signUpResponse.status} ${JSON.stringify(signUpResponse.body)}`,
      );
    }

    // Extract session token from Set-Cookie header (better-auth tokens need full signature)
    const userData = signUpResponse.body;
    let sessionToken = '';

    const setCookieHeader = signUpResponse.headers['set-cookie'];

    if (setCookieHeader) {
      const sessionCookie = setCookieHeader.find((cookie: string) =>
        cookie.includes('pantry.session_token='),
      );

      if (sessionCookie) {
        const match = sessionCookie.match(/pantry\.session_token=([^;]+)/);
        if (match) {
          sessionToken = decodeURIComponent(match[1]);
        }
      }
    }

    // Fallback to body token if cookie not found
    if (!sessionToken) {
      sessionToken = userData.token;
    }

    if (!sessionToken) {
      throw new Error(
        `No session token found in signup response. Body: ${JSON.stringify(userData)}`,
      );
    }

    const authUserId = userData.user?.id || userData.id;
    let businessUserId = authUserId; // Default fallback

    // If we have database access, try to find the business user that should have been created
    if (db) {
      try {
        // Wait a bit for the auth-sync service to create the business user
        await new Promise(resolve => setTimeout(resolve, 100));
        
        const businessUser = await db
          .selectFrom('user')
          .select('id')
          .where('auth_user_id', '=', authUserId)
          .executeTakeFirst();
        
        if (businessUser) {
          businessUserId = businessUser.id;
        } else {
          console.warn(`No business user found for auth user ${authUserId}. Auth-sync might have failed.`);
        }
      } catch (error) {
        console.warn(`Error looking up business user for auth user ${authUserId}:`, error);
      }
    }

    return {
      userId: businessUserId,
      authUserId: authUserId,
      sessionToken,
      email,
    };
  }
}
