import { NestFactory } from '@nestjs/core';
import type { INestApplication } from '@nestjs/common';
import { MigrationContextModule } from './migration-context.module.js';

/**
 * Creates a minimal NestJS application context for migration scripts
 * Provides access to dependency injection container without full app overhead
 */
export async function createMigrationContext(): Promise<INestApplication> {
  const app = await NestFactory.create(MigrationContextModule, {
    logger: false, // Disable NestJS logging to avoid noise in migration scripts
  });

  // Enable shutdown hooks to ensure proper cleanup
  app.enableShutdownHooks();

  // Initialize the application to ensure all modules are properly set up
  await app.init();

  return app;
}

/**
 * Helper to properly cleanup the migration context
 */
export async function closeMigrationContext(
  app: INestApplication,
): Promise<void> {
  await app.close();
}
