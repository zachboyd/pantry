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
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';

      this.logger.log(
        `🔄 Creating business user for auth user: ${authUser.id} (${authUser.email || 'no email'})`,
      );

      // Create business user record
      const businessUser = await this.db
        .insertInto('user')
        .values({
          id: crypto.randomUUID(),
          auth_user_id: authUser.id,
          email: authUser.email || null,
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
      this.logger.error(
        {
          id: authUser.id,
          email: authUser.email || null,
        },
        'Auth user that failed:',
      );
    }
  }

  /**
   * Syncs auth user updates to business user record
   * Handles any field changes including email, name, image, etc.
   */
  async syncUserUpdate(authUser: BetterAuthUser): Promise<void> {
    try {
      this.logger.log(
        `🔄 Syncing user update for auth user: ${authUser.id} (${authUser.email || 'no email'})`,
      );

      // Extract first and last name from auth user's name field
      const nameParts = authUser.name.trim().split(' ');
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';

      // Update business user record with all relevant fields
      const result = await this.db
        .updateTable('user')
        .set({
          email: authUser.email || null,
          first_name: firstName,
          last_name: lastName,
          display_name: authUser.name,
          avatar_url: authUser.image || null,
          updated_at: new Date(),
        })
        .where('auth_user_id', '=', authUser.id)
        .executeTakeFirst();

      if (result.numUpdatedRows === 0n) {
        this.logger.warn(
          `⚠️ No business user found for auth user ${authUser.id} during sync`,
        );
        return;
      }

      this.logger.log(
        `✅ Business user updated successfully for auth user ${authUser.id}`,
      );
    } catch (error) {
      // Log error but don't throw - we don't want to break the auth flow
      this.logger.error(
        error,
        '❌ Failed to sync user update to business user',
      );
      this.logger.error(
        {
          authUserId: authUser.id,
          email: authUser.email || null,
          name: authUser.name,
        },
        'User sync details:',
      );
    }
  }

  /**
   * Finds a business user by auth user ID
   * Used to detect email changes in the email verification callback
   */
  async findUserByAuthId(
    authUserId: string,
  ): Promise<{ email: string } | null> {
    try {
      const user = await this.db
        .selectFrom('user')
        .select(['email'])
        .where('auth_user_id', '=', authUserId)
        .executeTakeFirst();

      return user ? { email: user.email || '' } : null;
    } catch (error) {
      this.logger.error(error, `Failed to find user by auth ID ${authUserId}`);
      return null;
    }
  }
}
