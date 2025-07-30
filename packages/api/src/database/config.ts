import { Kysely, PostgresDialect } from 'kysely';
import { Pool } from 'pg';
import { DB } from '../generated/database.js';

export function createDatabase(): Kysely<DB> {
  const dialect = new PostgresDialect({
    pool: new Pool({
      connectionString: process.env.DATABASE_URL,
    }),
  });

  return new Kysely<DB>({
    dialect,
  });
}

export const db = createDatabase();
