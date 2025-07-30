import type { Insertable } from 'kysely';
import type { Message, TypingIndicator } from '../../generated/database.js';

/**
 * Interface for Message repository operations (pure data access)
 */
export interface MessageRepository {
  /**
   * Save a message to the database
   * @param message - Message data to save
   * @returns Promise with the saved message
   */
  save(message: Insertable<Message>): Promise<Message>;

  /**
   * Get recent messages for a chat
   * @param chatId - Chat ID to get messages for
   * @param limit - Maximum number of messages to return
   * @returns Promise with recent messages in chronological order
   */
  getRecentMessages(chatId: string, limit: number): Promise<Message[]>;
}

/**
 * Interface for Message service operations (business logic)
 */
export interface MessageService {
  /**
   * Save a message to the database and emit events for further processing
   * @param message - Message data to save
   * @returns Promise with the saved message
   */
  save(message: Insertable<Message>): Promise<Message>;
}

/**
 * Interface for Typing Indicator repository operations (pure data access)
 */
export interface TypingIndicatorRepository {
  /**
   * Save a typing indicator to the database using upsert on [chat_id, user_id]
   * @param typingIndicator - Typing indicator data to save
   * @returns Promise with the saved typing indicator
   */
  save(typingIndicator: Insertable<TypingIndicator>): Promise<TypingIndicator>;
}

/**
 * Interface for Typing Indicator service operations
 */
export interface TypingIndicatorService {
  /**
   * Save a typing indicator to the database using upsert on [chat_id, user_id]
   * @param typingIndicator - Typing indicator data to save
   * @returns Promise with the saved typing indicator
   */
  save(typingIndicator: Insertable<TypingIndicator>): Promise<TypingIndicator>;
}
