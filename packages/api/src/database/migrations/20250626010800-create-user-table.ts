import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Drop old user table if it exists (from old migration)
  await db.schema.dropTable('user').ifExists().execute();

  // Create business user table
  await db.schema
    .createTable('user')
    .addColumn('id', 'uuid', (col) => col.primaryKey().notNull())
    .addColumn('auth_user_id', 'text', (col) =>
      col.unique().references('auth_user.id').onDelete('cascade'),
    )
    .addColumn('email', 'varchar', (col) => col.unique())
    .addColumn('first_name', 'varchar(50)', (col) => col.notNull())
    .addColumn('last_name', 'varchar(50)', (col) => col.notNull())
    .addColumn('display_name', 'varchar(100)')
    .addColumn('avatar_url', 'text')
    .addColumn('phone', 'varchar(20)')
    .addColumn('birth_date', 'date')
    .addColumn('preferences', 'jsonb')
    .addColumn('managed_by', 'uuid', (col) => col.references('user.id'))
    .addColumn('relationship_to_manager', 'varchar(50)')
    .addColumn('created_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updated_at', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create indexes
  await db.schema
    .createIndex('idx_user_auth_user_id')
    .on('user')
    .column('auth_user_id')
    .execute();

  await db.schema
    .createIndex('idx_user_email')
    .on('user')
    .column('email')
    .execute();

  // Create index for managed_by relationships
  await db.schema
    .createIndex('idx_user_managed_by')
    .on('user')
    .column('managed_by')
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  // Drop user table
  await db.schema.dropTable('user').ifExists().execute();
}
