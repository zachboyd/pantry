import type { Message } from '../../../generated/database.js';

/**
 * Event emitted when a message is saved to the database
 * Used to trigger downstream processing like AI analysis
 */
export class MessageSavedEvent {
  constructor(public readonly message: Message) {}
}
