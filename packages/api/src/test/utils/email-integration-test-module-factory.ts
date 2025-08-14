import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import {
  NestExpressApplication,
  ExpressAdapter,
} from '@nestjs/platform-express';
import request from 'supertest';
import { toNodeHandler } from 'better-auth/node';
import express from 'express';
import { AppModule } from '../../app.module.js';
import { TOKENS } from '../../common/tokens.js';
import { TestDatabaseService } from './test-database.service.js';
import type { Kysely } from 'kysely';
import type { DB } from '../../generated/database.js';
import type { AuthFactory } from '../../modules/auth/auth.factory.js';

/**
 * Factory for creating NestJS application instances with full email integration for email testing
 * This includes Better Auth email verification functionality with real email service integration
 * Use this ONLY for testing email-specific functionality
 */
export class EmailIntegrationTestModuleFactory {
  /**
   * Creates a full NestJS application with email integration enabled
   * This will trigger actual email sending via AWS SES for email verification
   */
  static async createApp(): Promise<{
    app: INestApplication;
    request: ReturnType<typeof request>;
    db: Kysely<DB>;
    testDbService: TestDatabaseService;
  }> {
    // Force real email service (not mock) for integration testing
    process.env.USE_MOCK_EMAIL_SERVICE = 'false';

    // Create test database service instance
    const testDbService = new TestDatabaseService();

    // Create Express instance (same as main.ts)
    const server = express();

    // Use the full AppModule with ALL services including email integration
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    })
      // Only override database service - email service will use real implementation due to env var
      .overrideProvider(TOKENS.DATABASE.SERVICE)
      .useValue(testDbService)
      .overrideProvider(TOKENS.DATABASE.CONNECTION)
      .useFactory({
        factory: () => testDbService.getConnection(),
      })
      .compile();

    // Create NestJS app with Express adapter (same as main.ts)
    const app = await moduleRef.createNestApplication<NestExpressApplication>(
      new ExpressAdapter(server),
      {
        bodyParser: false,
      },
    );

    // Get AuthFactory to mount better-auth routes (with email integration enabled)
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
   * Properly cleanup the email integration test application
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
        await db.deleteFrom(table as keyof DB).execute();
      } catch (error) {
        // Table might not exist in test database, continue
        console.warn(`Failed to clean table ${table}:`, error);
      }
    }
  }
}
