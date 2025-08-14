import { Inject, Injectable } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { createAuth } from './auth.config.js';
import type { AuthSyncService, BetterAuthUser } from './auth.types.js';
import type { EmailService } from '../email/email.types.js';
import type { ConfigService } from '../config/config.types.js';
import type { SecondaryStorage } from './auth-secondary-storage.service.js';

@Injectable()
export class AuthFactory {
  constructor(
    @Inject(TOKENS.AUTH.AUTH_SYNC_SERVICE)
    private authSyncService: AuthSyncService,
    @Inject(TOKENS.EMAIL.SERVICE)
    private emailService: EmailService,
    @Inject(TOKENS.CONFIG.SERVICE)
    private configService: ConfigService,
    @Inject(TOKENS.AUTH.SECONDARY_STORAGE)
    private secondaryStorage: SecondaryStorage,
  ) {}

  /**
   * Creates a better-auth instance with user sync callbacks and email service
   */
  createAuthInstance(): ReturnType<typeof createAuth> {
    const onUserCreated = async (user: BetterAuthUser) => {
      await this.authSyncService.createBusinessUser(user);
    };

    const onUserUpdated = async (user: BetterAuthUser) => {
      await this.authSyncService.syncUserUpdate(user);
    };

    const onEmailVerification = async ({
      user,
      url,
      token: _token,
    }: {
      user: BetterAuthUser;
      url: string;
      token: string;
    }) => {
      const baseUrl = this.configService.config.app.url;
      const useMockService = this.configService.config.aws.ses.useMockService;

      await this.emailService.sendTemplateEmail({
        template: 'email-verification',
        to: user.email,
        variables: {
          userName: user.name || 'User',
          appName: 'Jeeves',
          userEmail: user.email,
          verificationUrl: url, // Use Better Auth's generated URL
          expiryHours: '1', // Default 1 hour from Better Auth
          supportEmail: 'support@jeevesapp.dev',
        },
        debug: useMockService
          ? {
              type: 'email_verification',
              curlCommand: `curl -X GET "${baseUrl}${new URL(url).pathname}${new URL(url).search}"`,
            }
          : undefined,
      });
    };

    const onEmailChangeVerification = async ({
      user,
      newEmail,
      url,
      token: _token,
    }: {
      user: BetterAuthUser;
      newEmail: string;
      url: string;
      token: string;
    }) => {
      const baseUrl = this.configService.config.app.url;
      const useMockService = this.configService.config.aws.ses.useMockService;

      await this.emailService.sendTemplateEmail({
        template: 'email-change-verification',
        to: user.email, // Verification sent to current email
        variables: {
          userName: user.name || 'User',
          appName: 'Jeeves',
          currentEmail: user.email,
          newEmail: newEmail,
          verificationUrl: url, // Use Better Auth's generated URL
          expiryHours: '1', // Default 1 hour from Better Auth
          supportEmail: 'support@jeevesapp.dev',
        },
        debug: useMockService
          ? {
              type: 'email_change_verification',
              curlCommand: `curl -X GET "${baseUrl}${new URL(url).pathname}${new URL(url).search}`,
            }
          : undefined,
      });
    };

    return createAuth({
      onUserCreated,
      onUserUpdated,
      onEmailVerification,
      onEmailChangeVerification,
      secondaryStorage: this.secondaryStorage,
      apiUrl: this.configService.config.app.url,
      secret: this.configService.config.betterAuth.secret,
    });
  }
}
