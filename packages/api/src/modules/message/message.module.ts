import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { MessageRepositoryModule } from './message-repository.module.js';
import { MessageServiceImpl } from './message.service.js';
import { TypingIndicatorServiceImpl } from './typing-indicator.service.js';

@Module({
  imports: [MessageRepositoryModule],
  providers: [
    {
      provide: TOKENS.MESSAGE.SERVICE,
      useClass: MessageServiceImpl,
    },
    {
      provide: TOKENS.MESSAGE.TYPING_INDICATOR_SERVICE,
      useClass: TypingIndicatorServiceImpl,
    },
  ],
  exports: [TOKENS.MESSAGE.SERVICE, TOKENS.MESSAGE.TYPING_INDICATOR_SERVICE],
})
export class MessageModule {}
