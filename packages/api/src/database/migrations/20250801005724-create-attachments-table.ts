import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create attachments table following PowerSync schema with additional columns
  await db.schema
    .createTable('attachments')
    .addColumn('id', 'text', (col) => col.primaryKey().notNull())
    .addColumn('filename', 'text')
    .addColumn('local_uri', 'text')
    .addColumn('timestamp', 'integer')
    .addColumn('size', 'integer')
    .addColumn('media_type', 'text')
    .addColumn('state', 'integer')
    .addColumn('household_id', 'uuid', (col) =>
      col.notNull().references('household.id').onDelete('cascade'),
    )
    .addColumn('user_id', 'uuid', (col) =>
      col.references('user.id').onDelete('cascade'),
    )
    .addColumn('created_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updated_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create indexes for efficient querying
  await db.schema
    .createIndex('idx_attachments_household')
    .on('attachments')
    .column('household_id')
    .execute();

  await db.schema
    .createIndex('idx_attachments_user')
    .on('attachments')
    .column('user_id')
    .execute();

  await db.schema
    .createIndex('idx_attachments_state')
    .on('attachments')
    .columns(['household_id', 'state'])
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('attachments').ifExists().execute();
}
