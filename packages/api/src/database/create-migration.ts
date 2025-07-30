#!/usr/bin/env tsx
import * as path from 'path';
import { promises as fs } from 'fs';

async function createMigration() {
  const args = process.argv.slice(2);
  const migrationName = args[0];

  if (!migrationName) {
    console.error('❌ Please provide a migration name');
    console.error('Usage: npm run db:migrate:create <migration-name>');
    process.exit(1);
  }

  const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
  const fileName = `${timestamp}-${migrationName}.ts`;
  const migrationPath = path.join(import.meta.dirname, 'migrations', fileName);

  const template = `import { Kysely } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Add your migration logic here
}

export async function down(db: Kysely<any>): Promise<void> {
  // Add your rollback logic here
}
`;

  await fs.writeFile(migrationPath, template);
  console.log(`✅ Created migration: ${fileName}`);
}

createMigration().catch(console.error);
