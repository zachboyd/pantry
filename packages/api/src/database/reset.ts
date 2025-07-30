#!/usr/bin/env tsx
import { promises as fs } from 'fs';
import * as path from 'path';
import { Migrator, FileMigrationProvider, NO_MIGRATIONS } from 'kysely';
import type { Kysely } from 'kysely';
import type { DB } from '../generated/database.js';
import { TOKENS } from '../common/tokens.js';
import {
  createMigrationContext,
  closeMigrationContext,
} from './migration-context.js';

async function resetDatabase() {
  const app = await createMigrationContext();

  try {
    // Get database connection via dependency injection
    const db = app.get<Kysely<DB>>(TOKENS.DATABASE.CONNECTION);

    console.log('🔄 Rolling back all migrations...');

    const migrator = new Migrator({
      db,
      provider: new FileMigrationProvider({
        fs,
        path,
        migrationFolder: path.join(import.meta.dirname, 'migrations'),
      }),
    });

    // Rollback all migrations to the beginning
    const { error: rollbackError, results: rollbackResults } =
      await migrator.migrateTo(NO_MIGRATIONS);

    rollbackResults?.forEach((result) => {
      if (result.status === 'Success') {
        console.log(
          `✅ Migration "${result.migrationName}" rolled back successfully`,
        );
      } else if (result.status === 'Error') {
        console.error(`❌ Migration "${result.migrationName}" rollback failed`);
      }
    });

    if (rollbackError) {
      console.error('❌ Migration rollback failed:', rollbackError);
      throw rollbackError;
    }

    console.log('✅ All migrations rolled back successfully');

    // Re-run migrations to latest
    console.log('🔄 Running migrations to latest...');
    const { error: migrateError, results: migrateResults } =
      await migrator.migrateToLatest();

    migrateResults?.forEach((result) => {
      if (result.status === 'Success') {
        console.log(
          `✅ Migration "${result.migrationName}" executed successfully`,
        );
      } else if (result.status === 'Error') {
        console.error(`❌ Migration "${result.migrationName}" failed`);
      }
    });

    if (migrateError) {
      console.error('❌ Migration failed:', migrateError);
      throw migrateError;
    }

    console.log('🎉 Database reset completed successfully');
  } catch (error) {
    console.error('❌ Database reset failed');
    console.error(error);
    process.exit(1);
  } finally {
    await closeMigrationContext(app);
  }
}

resetDatabase().catch(console.error);
