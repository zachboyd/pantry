import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserModule } from '../user/user.module.js';
import { EmailModule } from '../email/email.module.js';
import { AppConfigModule } from '../config/config.module.js';
import { AuthSyncServiceImpl } from './auth-sync.service.js';
import { AuthFactory } from './auth.factory.js';
import { AuthGuard } from './auth.guard.js';
import { AuthServiceImpl } from './auth.service.js';
import { AuthUserRepositoryImpl } from './auth-user.repository.js';
import { AuthUserServiceImpl } from './auth-user.service.js';

@Module({
  imports: [UserModule, EmailModule, AppConfigModule],
  providers: [
    {
      provide: TOKENS.AUTH.SERVICE,
      useClass: AuthServiceImpl,
    },
    {
      provide: TOKENS.AUTH.GUARD,
      useClass: AuthGuard,
    },
    {
      provide: TOKENS.AUTH.FACTORY,
      useClass: AuthFactory,
    },
    {
      provide: TOKENS.AUTH.AUTH_SYNC_SERVICE,
      useClass: AuthSyncServiceImpl,
    },
    {
      provide: TOKENS.AUTH.USER_REPOSITORY,
      useClass: AuthUserRepositoryImpl,
    },
    {
      provide: TOKENS.AUTH.USER_SERVICE,
      useClass: AuthUserServiceImpl,
    },
  ],
  exports: [
    TOKENS.AUTH.SERVICE,
    TOKENS.AUTH.GUARD,
    TOKENS.AUTH.FACTORY,
    TOKENS.AUTH.AUTH_SYNC_SERVICE,
    TOKENS.AUTH.USER_SERVICE,
    TOKENS.AUTH.USER_REPOSITORY,
  ],
})
export class AuthModule {}
