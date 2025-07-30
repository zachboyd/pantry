import type { Kysely } from 'kysely';
import type { DB } from '../../generated/database.js';

export interface DatabaseService {
  getConnection(): Kysely<DB>;
}
