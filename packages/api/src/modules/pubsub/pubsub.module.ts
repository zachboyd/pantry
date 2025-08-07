import { Module, Global } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { PubSubServiceImpl } from './pubsub.service.js';

@Global()
@Module({
  providers: [
    {
      provide: TOKENS.PUBSUB.SERVICE,
      useClass: PubSubServiceImpl,
    },
  ],
  exports: [TOKENS.PUBSUB.SERVICE],
})
export class PubSubModule {}
