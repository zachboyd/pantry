import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create Better Auth user table
  await db.schema
    .createTable('auth_user')
    .addColumn('id', 'text', (col) => col.primaryKey().notNull())
    .addColumn('name', 'text', (col) => col.notNull())
    .addColumn('email', 'text', (col) => col.notNull().unique())
    .addColumn('emailVerified', 'boolean', (col) =>
      col.notNull().defaultTo(false),
    )
    .addColumn('image', 'text')
    .addColumn('createdAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updatedAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create Better Auth session table
  await db.schema
    .createTable('auth_session')
    .addColumn('id', 'text', (col) => col.primaryKey().notNull())
    .addColumn('expiresAt', 'timestamptz', (col) => col.notNull())
    .addColumn('token', 'text', (col) => col.notNull().unique())
    .addColumn('createdAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updatedAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('ipAddress', 'text')
    .addColumn('userAgent', 'text')
    .addColumn('userId', 'text', (col) =>
      col.notNull().references('auth_user.id').onDelete('cascade'),
    )
    .execute();

  // Create Better Auth account table
  await db.schema
    .createTable('auth_account')
    .addColumn('id', 'text', (col) => col.primaryKey().notNull())
    .addColumn('accountId', 'text', (col) => col.notNull())
    .addColumn('providerId', 'text', (col) => col.notNull())
    .addColumn('userId', 'text', (col) =>
      col.notNull().references('auth_user.id').onDelete('cascade'),
    )
    .addColumn('accessToken', 'text')
    .addColumn('refreshToken', 'text')
    .addColumn('idToken', 'text')
    .addColumn('accessTokenExpiresAt', 'timestamptz')
    .addColumn('refreshTokenExpiresAt', 'timestamptz')
    .addColumn('scope', 'text')
    .addColumn('password', 'text')
    .addColumn('createdAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .addColumn('updatedAt', 'timestamptz', (col) =>
      col.notNull().defaultTo(sql`now()`),
    )
    .execute();

  // Create Better Auth verification table
  await db.schema
    .createTable('auth_verification')
    .addColumn('id', 'text', (col) => col.primaryKey().notNull())
    .addColumn('identifier', 'text', (col) => col.notNull())
    .addColumn('value', 'text', (col) => col.notNull())
    .addColumn('expiresAt', 'timestamptz', (col) => col.notNull())
    .addColumn('createdAt', 'timestamptz', (col) => col.defaultTo(sql`now()`))
    .addColumn('updatedAt', 'timestamptz', (col) => col.defaultTo(sql`now()`))
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  // Drop Better Auth tables in reverse order (due to foreign key constraints)
  await db.schema.dropTable('auth_verification').ifExists().execute();
  await db.schema.dropTable('auth_account').ifExists().execute();
  await db.schema.dropTable('auth_session').ifExists().execute();
  await db.schema.dropTable('auth_user').ifExists().execute();
}
