import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  // Create household role enum
  await db.schema
    .createType('household_role')
    .asEnum(['manager', 'member', 'ai'])
    .execute();

  // Create message_type enum
  await db.schema
    .createType('message_type')
    .asEnum(['text', 'system', 'ai', 'location', 'task_created'])
    .execute();

  // Create household table
  await db.schema
    .createTable('household')
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

  // Add primary_household_id foreign key constraint to user table
  await db.schema
    .alterTable('user')
    .addForeignKeyConstraint(
      'fk_user_primary_household',
      ['primary_household_id'],
      'household',
      ['id'],
    )
    .onDelete('set null')
    .execute();

  // Create household_member table
  await db.schema
    .createTable('household_member')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('household_id', 'uuid', (col) =>
      col.notNull().references('household.id').onDelete('cascade'),
    )
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('user.id').onDelete('cascade'),
    )
    .addColumn('role', sql`household_role`, (col) =>
      col.notNull().defaultTo('member'),
    )
    .addColumn('joined_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create pantry table
  await db.schema
    .createTable('pantry')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('household_id', 'uuid', (col) =>
      col.notNull().references('household.id').onDelete('cascade'),
    )
    .addColumn('name', 'varchar(200)', (col) => col.notNull())
    .addColumn('description', 'text')
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
    .addColumn('household_id', 'uuid', (col) =>
      col.notNull().references('household.id').onDelete('cascade'),
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
    .addColumn('household_id', 'uuid', (col) =>
      col.notNull().references('household.id').onDelete('cascade'),
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
    .createIndex('idx_household_member_unique')
    .on('household_member')
    .columns(['household_id', 'user_id'])
    .unique()
    .execute();

  await db.schema
    .createIndex('idx_household_member_user')
    .on('household_member')
    .column('user_id')
    .execute();

  await db.schema
    .createIndex('idx_pantry_household')
    .on('pantry')
    .column('household_id')
    .execute();

  await db.schema
    .createIndex('idx_message_household_created')
    .on('message')
    .columns(['household_id', 'created_at'])
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
    .columns(['household_id', 'user_id'])
    .unique()
    .execute();

  await db.schema
    .createIndex('idx_typing_indicator_active')
    .on('typing_indicator')
    .columns(['household_id', 'is_typing', 'expires_at'])
    .execute();
}

export async function down(db: Kysely<unknown>): Promise<void> {
  // Drop foreign key constraint from user table first
  await db.schema
    .alterTable('user')
    .dropConstraint('fk_user_primary_household')
    .ifExists()
    .execute();

  // Drop tables in reverse dependency order
  await db.schema.dropTable('typing_indicator').ifExists().execute();
  await db.schema.dropTable('message_read').ifExists().execute();
  await db.schema.dropTable('message').ifExists().execute();
  await db.schema.dropTable('pantry').ifExists().execute();
  await db.schema.dropTable('household_member').ifExists().execute();
  await db.schema.dropTable('household').ifExists().execute();

  // Drop enums
  await db.schema.dropType('message_type').ifExists().execute();
  await db.schema.dropType('household_role').ifExists().execute();
}
