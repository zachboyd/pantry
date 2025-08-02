import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  // Enable pg_cron extension for scheduled database tasks
  await sql`CREATE EXTENSION IF NOT EXISTS pg_cron`.execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  // Drop pg_cron extension
  await sql`DROP EXTENSION IF EXISTS pg_cron`.execute(db);
}
