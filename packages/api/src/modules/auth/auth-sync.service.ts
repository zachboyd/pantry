import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { DB } from '../../generated/database.js';
import type { AuthSyncService, BetterAuthUser } from './auth.types.js';

@Injectable()
export class AuthSyncServiceImpl implements AuthSyncService {
  private readonly logger = new Logger(AuthSyncServiceImpl.name);

  constructor(@Inject(TOKENS.DATABASE.CONNECTION) private db: Kysely<DB>) {}

  /**
   * Creates a business user record after auth user signup
   */
  async createBusinessUser(authUser: BetterAuthUser): Promise<void> {
    try {
      // Extract first and last name from auth user's name field
      const nameParts = authUser.name.trim().split(' ');
      const firstName = nameParts[0] || 'User';
      const lastName = nameParts.slice(1).join(' ') || '';

      this.logger.log(
        `🔄 Creating business user for auth user: ${authUser.id} (${authUser.email})`,
      );

      // Create business user record
      const businessUser = await this.db
        .insertInto('user')
        .values({
          id: crypto.randomUUID(),
          auth_user_id: authUser.id,
          email: authUser.email,
          first_name: firstName,
          last_name: lastName,
          display_name: authUser.name,
          avatar_url: authUser.image || null,
          created_at: new Date(),
          updated_at: new Date(),
        })
        .returning('id')
        .executeTakeFirstOrThrow();

      this.logger.log(
        `✅ Business user created successfully: ${businessUser.id} for auth user ${authUser.id}`,
      );
    } catch (error) {
      // Log error but don't throw - we don't want to break auth signup
      this.logger.error(error, '❌ Failed to create business user record');
      this.logger.error('Auth user that failed:', {
        id: authUser.id,
        email: authUser.email,
      });
    }
  }
}
