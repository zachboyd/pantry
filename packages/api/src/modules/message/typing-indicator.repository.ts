import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import type { TypingIndicator } from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type { TypingIndicatorRepository } from './message.types.js';

@Injectable()
export class TypingIndicatorRepositoryImpl
  implements TypingIndicatorRepository
{
  private readonly logger = new Logger(TypingIndicatorRepositoryImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
  ) {}

  async save(
    typingIndicator: Insertable<TypingIndicator>,
  ): Promise<TypingIndicator> {
    this.logger.log(
      `Saving typing indicator for user ${typingIndicator.user_id} in household ${typingIndicator.household_id}`,
    );

    const db = this.databaseService.getConnection();

    try {
      const [savedIndicator] = await db
        .insertInto('typing_indicator')
        .values({
          id: typingIndicator.id || uuidv4(), // Generate UUID if not provided
          household_id: typingIndicator.household_id,
          user_id: typingIndicator.user_id,
          is_typing: typingIndicator.is_typing,
          // Let database handle timestamps if not provided
          ...(typingIndicator.created_at && {
            created_at: typingIndicator.created_at,
          }),
          ...(typingIndicator.last_typing_at && {
            last_typing_at: typingIndicator.last_typing_at,
          }),
          ...(typingIndicator.expires_at && {
            expires_at: typingIndicator.expires_at,
          }),
        })
        .onConflict((oc) =>
          oc.columns(['household_id', 'user_id']).doUpdateSet({
            is_typing: typingIndicator.is_typing,
            // Always update last_typing_at to current timestamp for fresh data
            last_typing_at: typingIndicator.last_typing_at || new Date().toISOString(),
            ...(typingIndicator.expires_at && {
              expires_at: typingIndicator.expires_at,
            }),
          }),
        )
        .returningAll()
        .execute();

      this.logger.log(
        `Typing indicator saved successfully: ${savedIndicator.id}`,
      );
      return savedIndicator as unknown as TypingIndicator;
    } catch (error) {
      this.logger.error(`Failed to save typing indicator:`, error);
      throw error;
    }
  }
}
