import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create message_type enum
  await db.schema
    .createType('message_type')
    .asEnum(['text', 'system', 'ai', 'location', 'task_created'])
    .execute();

  // Create chat table
  await db.schema
    .createTable('chat')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('name', 'varchar(200)', (col) => col.notNull())
    .addColumn('description', 'text')
    .addColumn('created_by', 'uuid', (col) =>
      col.notNull().references('user.id').onDelete('cascade'),
    )
    .addColumn('created_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updated_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create message table
  await db.schema
    .createTable('message')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('chat_id', 'uuid', (col) =>
      col.notNull().references('chat.id').onDelete('cascade'),
    )
    .addColumn('user_id', 'uuid', (col) =>
      col.references('user.id').onDelete('cascade'),
    )
    .addColumn('content', 'text', (col) => col.notNull())
    .addColumn('message_type', sql`message_type`, (col) => col.notNull())
    .addColumn('metadata', 'jsonb')
    .addColumn('created_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updated_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create message_read table
  await db.schema
    .createTable('message_read')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('message_id', 'uuid', (col) =>
      col.notNull().references('message.id').onDelete('cascade'),
    )
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('user.id').onDelete('cascade'),
    )
    .addColumn('read_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create typing_indicator table
  await db.schema
    .createTable('typing_indicator')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('chat_id', 'uuid', (col) =>
      col.notNull().references('chat.id').onDelete('cascade'),
    )
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('user.id').onDelete('cascade'),
    )
    .addColumn('is_typing', 'boolean', (col) => col.notNull().defaultTo(true))
    .addColumn('last_typing_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('expires_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now() + interval '15 seconds'`),
    )
    .addColumn('created_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create indexes
  await db.schema
    .createIndex('idx_message_chat_created')
    .on('message')
    .columns(['chat_id', 'created_at'])
    .execute();

  await db.schema
    .createIndex('idx_message_read_unique')
    .on('message_read')
    .columns(['message_id', 'user_id'])
    .unique()
    .execute();

  await db.schema
    .createIndex('idx_message_read_user_activity')
    .on('message_read')
    .columns(['user_id', 'read_at'])
    .execute();

  await db.schema
    .createIndex('idx_message_read_progression')
    .on('message_read')
    .columns(['message_id', 'read_at'])
    .execute();

  await db.schema
    .createIndex('idx_typing_indicator_unique')
    .on('typing_indicator')
    .columns(['chat_id', 'user_id'])
    .unique()
    .execute();

  await db.schema
    .createIndex('idx_typing_indicator_active')
    .on('typing_indicator')
    .columns(['chat_id', 'is_typing', 'expires_at'])
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  // Drop tables in reverse dependency order
  await db.schema.dropTable('typing_indicator').ifExists().execute();
  await db.schema.dropTable('message_read').ifExists().execute();
  await db.schema.dropTable('message').ifExists().execute();
  await db.schema.dropTable('chat').ifExists().execute();

  // Drop enums
  await db.schema.dropType('message_type').ifExists().execute();
}
