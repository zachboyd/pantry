import { Injectable, Inject } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { DB } from '../../generated/database.js';
import type { AuthUserRepository, AuthUserRecord } from './auth-user.types.js';

@Injectable()
export class AuthUserRepositoryImpl implements AuthUserRepository {
  constructor(
    @Inject(TOKENS.DATABASE.CONNECTION)
    private readonly db: Kysely<DB>,
  ) {}

  async getById(id: string): Promise<AuthUserRecord | null> {
    return (
      (await this.db
        .selectFrom('auth_user')
        .selectAll()
        .where('id', '=', id)
        .executeTakeFirst()) ?? null
    );
  }

  async getByEmail(email: string): Promise<AuthUserRecord | null> {
    return (
      (await this.db
        .selectFrom('auth_user')
        .selectAll()
        .where('email', '=', email)
        .executeTakeFirst()) ?? null
    );
  }
}
