import { Inject, Injectable } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { createAuth } from './auth.config.js';
import type { AuthSyncService, BetterAuthUser } from './auth.types.js';
import type { EmailService } from '../email/email.types.js';
import type { ConfigService } from '../config/config.types.js';

@Injectable()
export class AuthFactory {
  constructor(
    @Inject(TOKENS.AUTH.AUTH_SYNC_SERVICE)
    private authSyncService: AuthSyncService,
    @Inject(TOKENS.EMAIL.SERVICE)
    private emailService: EmailService,
    @Inject(TOKENS.CONFIG.SERVICE)
    private configService: ConfigService,
  ) {}

  /**
   * Creates a better-auth instance with user sync callback and email service
   */
  createAuthInstance(): ReturnType<typeof createAuth> {
    const onUserCreated = async (user: BetterAuthUser) => {
      await this.authSyncService.createBusinessUser(user);
    };

    return createAuth({
      onUserCreated,
      emailService: this.emailService,
      apiUrl: this.configService.config.app.url,
      secret: this.configService.config.betterAuth.secret,
    });
  }
}
