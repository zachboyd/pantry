import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  // Schedule cleanup of expired typing indicators (every 10 minutes)
  await sql`
    SELECT cron.schedule(
      'cleanup-expired-typing-indicators',
      '*/10 * * * *',
      $$DELETE FROM typing_indicator WHERE expires_at < NOW()$$
    )
  `.execute(db);

  // Schedule marking overdue tasks as expired (every hour)
  await sql`
    SELECT cron.schedule(
      'mark-overdue-tasks-expired', 
      '0 * * * *',
      $$UPDATE task SET status = 'expired', updated_at = NOW() 
        WHERE status = 'pending' AND due_date < NOW()$$
    )
  `.execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  // Remove scheduled jobs
  await sql`SELECT cron.unschedule('cleanup-expired-typing-indicators')`.execute(
    db,
  );
  await sql`SELECT cron.unschedule('mark-overdue-tasks-expired')`.execute(db);
}
