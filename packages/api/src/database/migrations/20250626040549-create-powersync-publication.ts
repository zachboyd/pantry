import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create PowerSync publication for all tables
  await sql`CREATE PUBLICATION powersync FOR ALL TABLES`.execute(db);

  console.log('✅ Created PowerSync publication for all tables');
}

export async function down(db: Kysely<any>): Promise<void> {
  // Drop PowerSync publication
  await sql`DROP PUBLICATION IF EXISTS powersync`.execute(db);

  console.log('✅ Dropped PowerSync publication');
}
