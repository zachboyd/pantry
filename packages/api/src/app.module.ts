import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { AuthGuard } from './modules/auth/auth.guard.js';
import { AuthModule } from './modules/auth/auth.module.js';
import { CacheModule } from './modules/cache/cache.module.js';
import { AppConfigModule } from './modules/config/config.module.js';
import { DatabaseModule } from './modules/database/database.module.js';
import { AppGraphQLModule } from './modules/graphql/graphql.module.js';
import { HealthModule } from './modules/health/health.module.js';
import { HouseholdModule } from './modules/household/household.module.js';
import { AppLoggerModule } from './modules/logger/logger.module.js';
import { MessageModule } from './modules/message/message.module.js';
import { EmailModule } from './modules/email/email.module.js';
import { PermissionModule } from './modules/permission/permission.module.js';
import { PubSubModule } from './modules/pubsub/pubsub.module.js';
import { SwaggerModule } from './modules/swagger/swagger.module.js';
import { UserModule } from './modules/user/user.module.js';

@Module({
  imports: [
    EventEmitterModule.forRoot(),
    AppConfigModule,
    AppLoggerModule,
    CacheModule,
    PubSubModule,
    SwaggerModule,
    AppGraphQLModule,
    HealthModule,
    DatabaseModule,
    AuthModule,
    PermissionModule,
    HouseholdModule,
    MessageModule,
    UserModule,
    EmailModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: AuthGuard,
    },
  ],
})
export class AppModule implements NestModule {
  configure(_consumer: MiddlewareConsumer) {}
}
