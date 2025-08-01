#!/usr/bin/env tsx
import * as path from 'path';
import { promises as fs } from 'fs';
import { Migrator, FileMigrationProvider, Kysely } from 'kysely';
import { createDatabase } from './config.js';
import { createMigrationContext } from './migration-context.js';
import { DB } from 'generated/database.js';
import { TOKENS } from 'common/tokens.js';

async function migrateToLatest() {
  const app = await createMigrationContext();

  const db = app.get<Kysely<DB>>(TOKENS.DATABASE.CONNECTION);

  const migrator = new Migrator({
    db,
    provider: new FileMigrationProvider({
      fs,
      path,
      migrationFolder: path.join(import.meta.dirname, 'migrations'),
    }),
  });

  const { error, results } = await migrator.migrateToLatest();

  results?.forEach((it) => {
    if (it.status === 'Success') {
      console.log(
        `✅ Migration "${it.migrationName}" was executed successfully`,
      );
    } else if (it.status === 'Error') {
      console.error(`❌ Failed to execute migration "${it.migrationName}"`);
    }
  });

  if (error) {
    console.error('❌ Migration failed');
    console.error(error);
    process.exit(1);
  }

  console.log('🎉 All migrations completed successfully');
  await db.destroy();
}

async function migrateDown() {
  const app = await createMigrationContext();

  const db = app.get<Kysely<DB>>(TOKENS.DATABASE.CONNECTION);

  const migrator = new Migrator({
    db,
    provider: new FileMigrationProvider({
      fs,
      path,
      migrationFolder: path.join(import.meta.dirname, 'migrations'),
    }),
  });

  const { error, results } = await migrator.migrateDown();

  results?.forEach((it) => {
    if (it.status === 'Success') {
      console.log(
        `✅ Migration "${it.migrationName}" was rolled back successfully`,
      );
    } else if (it.status === 'Error') {
      console.error(`❌ Failed to rollback migration "${it.migrationName}"`);
    }
  });

  if (error) {
    console.error('❌ Migration rollback failed');
    console.error(error);
    process.exit(1);
  }

  console.log('🎉 Migration rolled back successfully');
  await db.destroy();
}

async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--down')) {
    await migrateDown();
  } else {
    await migrateToLatest();
  }
}

main().catch(console.error);
