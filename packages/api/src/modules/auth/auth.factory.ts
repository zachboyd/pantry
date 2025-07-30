import { Inject, Injectable } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { createAuth } from './auth.config.js';
import type { AuthSyncService, BetterAuthUser } from './auth.types.js';

@Injectable()
export class AuthFactory {
  constructor(
    @Inject(TOKENS.AUTH.AUTH_SYNC_SERVICE)
    private authSyncService: AuthSyncService,
  ) {}

  /**
   * Creates a better-auth instance with user sync callback
   */
  createAuthInstance(): ReturnType<typeof createAuth> {
    const onUserCreated = async (user: BetterAuthUser) => {
      await this.authSyncService.createBusinessUser(user);
    };

    return createAuth(onUserCreated);
  }
}
