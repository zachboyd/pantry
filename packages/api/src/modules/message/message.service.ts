import { Inject, Injectable, Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import type { Insertable } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import { EVENTS } from '../../common/events.js';
import type { Message } from '../../generated/database.js';
import { MessageSavedEvent } from './events/message-saved.event.js';
import type { MessageRepository, MessageService } from './message.types.js';

@Injectable()
export class MessageServiceImpl implements MessageService {
  private readonly logger = new Logger(MessageServiceImpl.name);

  constructor(
    @Inject(TOKENS.MESSAGE.REPOSITORY)
    private readonly messageRepository: MessageRepository,
    @Inject(EventEmitter2)
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async save(message: Insertable<Message>): Promise<Message> {
    this.logger.log(`Saving message for household ${message.household_id}`);

    try {
      // Save message using repository
      const savedMessage = await this.messageRepository.save(message);

      this.logger.log(`Message saved successfully: ${savedMessage.id}`);

      // Emit event for downstream processing (AI, notifications, etc.)
      this.eventEmitter.emit(
        EVENTS.MESSAGE.SAVED,
        new MessageSavedEvent(savedMessage),
      );

      return savedMessage;
    } catch (error) {
      this.logger.error(`Failed to save message:`, error);
      throw error;
    }
  }
}
