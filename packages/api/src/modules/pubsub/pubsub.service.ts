import { Injectable, Inject, Logger } from '@nestjs/common';
import { RedisPubSub } from 'graphql-redis-subscriptions';
import { TOKENS } from '../../common/tokens.js';
import type { UserRecord } from '../user/user.types.js';
import type {
  PubSubService,
  UserUpdatedEvent,
  RedisConfig,
} from './pubsub.types.js';

@Injectable()
export class PubSubServiceImpl implements PubSubService {
  private readonly logger = new Logger(PubSubServiceImpl.name);
  private readonly pubsub: RedisPubSub;

  constructor(
    @Inject(TOKENS.PUBSUB.REDIS_CONFIG)
    private readonly redisConfig: RedisConfig,
  ) {
    this.pubsub = new RedisPubSub({
      connection: this.redisConfig.url,
    });

    this.logger.log(
      `PubSub service initialized with Redis: ${this.redisConfig.url}`,
    );
  }

  async publishUserUpdated(
    userId: string,
    userData: UserRecord,
  ): Promise<void> {
    try {
      const eventName = this.getUserUpdatedEventName(userId);
      await this.pubsub.publish(eventName, {
        userUpdated: userData,
      });

      this.logger.debug(`Published user update for user ${userId}`);
    } catch (error) {
      this.logger.error(
        `Failed to publish user update for user ${userId}:`,
        error,
      );
    }
  }

  getUserUpdatedIterator(userId: string): AsyncIterator<UserUpdatedEvent> {
    const eventName = this.getUserUpdatedEventName(userId);
    return this.pubsub.asyncIterator(eventName);
  }

  private getUserUpdatedEventName(userId: string): string {
    return `USER_UPDATED_${userId}`;
  }
}
