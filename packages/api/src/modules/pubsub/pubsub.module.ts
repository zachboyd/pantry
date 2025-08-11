import { Module, Global } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import { PubSubServiceImpl } from './pubsub.service.js';
import type { RedisConfig } from './pubsub.types.js';
import type { ConfigService } from '../config/config.types.js';

@Global()
@Module({
  imports: [AppConfigModule],
  providers: [
    {
      provide: TOKENS.PUBSUB.REDIS_CONFIG,
      useFactory: (configService: ConfigService): RedisConfig => {
        return {
          url: configService.config.redis.url,
        };
      },
      inject: [TOKENS.CONFIG.SERVICE],
    },
    {
      provide: TOKENS.PUBSUB.SERVICE,
      useClass: PubSubServiceImpl,
    },
  ],
  exports: [TOKENS.PUBSUB.SERVICE],
})
export class PubSubModule {}
