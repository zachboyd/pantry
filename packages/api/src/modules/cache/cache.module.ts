import { Module, Global, Logger } from '@nestjs/common';
import { createCache } from 'cache-manager';
import { Keyv } from 'keyv';
import KeyvRedis from '@keyv/redis';
import { TOKENS } from '../../common/tokens.js';
import { CacheHelper } from './cache.helper.js';
import type { ConfigService } from '../config/config.types.js';

@Global()
@Module({
  providers: [
    {
      provide: TOKENS.CACHE.REDIS_CLIENT,
      useFactory: (configService: ConfigService) => {
        const logger = new Logger('CacheModule');
        const redisUrl = configService.config.redis.url;

        // Create Keyv with Redis store
        const keyv = new Keyv({
          store: new KeyvRedis(redisUrl),
          namespace: 'jeeves-api',
        });

        keyv.on('error', (error) => {
          logger.error('Redis cache connection error:', error);
        });

        // Log successful Redis connection
        logger.log(`Initializing Redis cache connection: ${redisUrl}`);

        return keyv;
      },
      inject: [TOKENS.CONFIG.SERVICE],
    },
    {
      provide: TOKENS.CACHE.MANAGER,
      useFactory: (keyvRedisStore: Keyv) => {
        return createCache({
          stores: [keyvRedisStore],
        });
      },
      inject: [TOKENS.CACHE.REDIS_CLIENT],
    },
    {
      provide: TOKENS.CACHE.HELPER,
      useClass: CacheHelper,
    },
  ],
  exports: [TOKENS.CACHE.MANAGER, TOKENS.CACHE.HELPER],
})
export class CacheModule {}
