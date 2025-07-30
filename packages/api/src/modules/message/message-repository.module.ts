import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { DatabaseModule } from '../database/database.module.js';
import { MessageRepositoryImpl } from './message.repository.js';
import { TypingIndicatorRepositoryImpl } from './typing-indicator.repository.js';

/**
 * Message Repository Module
 *
 * Provides MessageRepository and TypingIndicatorRepository for data access.
 * Use this module when you need message data access without business logic.
 *
 * This avoids circular dependencies since it doesn't depend on WorkerModule.
 */
@Module({
  imports: [DatabaseModule],
  providers: [
    {
      provide: TOKENS.MESSAGE.REPOSITORY,
      useClass: MessageRepositoryImpl,
    },
    {
      provide: TOKENS.MESSAGE.TYPING_INDICATOR_REPOSITORY,
      useClass: TypingIndicatorRepositoryImpl,
    },
  ],
  exports: [
    TOKENS.MESSAGE.REPOSITORY,
    TOKENS.MESSAGE.TYPING_INDICATOR_REPOSITORY,
  ],
})
export class MessageRepositoryModule {}
