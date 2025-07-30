import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import type { Message } from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type { MessageRepository } from './message.types.js';

@Injectable()
export class MessageRepositoryImpl implements MessageRepository {
  private readonly logger = new Logger(MessageRepositoryImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
  ) {}

  async save(message: Insertable<Message>): Promise<Message> {
    this.logger.log(`Saving message for household ${message.household_id}`);

    const db = this.databaseService.getConnection();

    try {
      // Save message to database using upsert
      // Preserve client timestamps for offline scenarios, fallback to DB defaults if not provided
      const [savedMessage] = await db
        .insertInto('message')
        .values({
          id: message.id || uuidv4(), // Generate UUID if not provided
          content: message.content,
          household_id: message.household_id,
          message_type: message.message_type,
          user_id: message.user_id,
          ...(message.metadata && { metadata: message.metadata as any }),
          // Preserve client timestamps if provided (important for offline writes)
          ...(message.created_at && { created_at: message.created_at }),
          ...(message.updated_at && { updated_at: message.updated_at }),
        })
        .onConflict((oc) =>
          oc.column('id').doUpdateSet({
            content: message.content,
            message_type: message.message_type,
            ...(message.metadata && { metadata: message.metadata as any }),
            // Update timestamp on conflict (server wins for modifications)
            ...(message.updated_at && { updated_at: message.updated_at }),
          }),
        )
        .returningAll()
        .execute();

      this.logger.log(`Message saved successfully: ${savedMessage.id}`);
      return savedMessage as unknown as Message;
    } catch (error) {
      this.logger.error(`Failed to save message:`, error);
      throw error;
    }
  }

  async getRecentMessages(householdId: string, limit: number): Promise<Message[]> {
    this.logger.debug(
      `Getting recent messages for household ${householdId}, limit: ${limit}`,
    );

    const db = this.databaseService.getConnection();

    try {
      // Simple database query - no business logic
      const messages = await db
        .selectFrom('message')
        .selectAll()
        .where('household_id', '=', householdId)
        .orderBy('created_at', 'desc')
        .limit(limit)
        .execute();

      // Return in chronological order (oldest first)
      const chronologicalMessages = messages.reverse();

      this.logger.debug(`Retrieved ${chronologicalMessages.length} messages`);
      return chronologicalMessages as unknown as Message[];
    } catch (error) {
      this.logger.error(
        `Failed to get recent messages for household ${householdId}:`,
        error,
      );
      return [];
    }
  }
}
