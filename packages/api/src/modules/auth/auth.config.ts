import { betterAuth } from 'better-auth';
import { PostgresDialect } from 'kysely';
import { Pool } from 'pg';

import type { BetterAuthUser } from './auth.types.js';
import type { EmailService } from '../email/email.types.js';
import { EMAIL_TEMPLATES } from '../email/templates/template-constants.js';

type AuthInstance = ReturnType<typeof betterAuth>;
type UserCreatedCallback = (user: BetterAuthUser) => Promise<void>;

export function createAuth(
  onUserCreated?: UserCreatedCallback,
  emailService?: EmailService,
): AuthInstance {
  return betterAuth({
    database: {
      dialect: new PostgresDialect({
        pool: new Pool({
          connectionString: process.env.DATABASE_URL,
        }),
      }),
      provider: 'pg',
    },
    secret: process.env.BETTER_AUTH_SECRET,
    baseURL: process.env.BETTER_AUTH_URL,
    basePath: '/api/auth',
    advanced: {
      cookiePrefix: 'jeeves',
    },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: false, // Allow login without verification
    },
    emailVerification: emailService
      ? {
          sendVerificationEmail: async ({ user, url, token: _token }) => {
            await emailService.sendTemplateEmail({
              template: EMAIL_TEMPLATES.EMAIL_VERIFICATION,
              to: user.email,
              variables: {
                userName: user.name || 'User',
                appName: 'Jeeves',
                userEmail: user.email,
                verificationUrl: url, // Use Better Auth's generated URL
                expiryHours: '1', // Default 1 hour from Better Auth
                supportEmail: 'support@jeevesapp.dev',
              },
            });
          },
          sendOnSignUp: true, // Send verification email after sign up
          sendOnSignIn: false, // Don't send on sign in (user can verify later)
          autoSignInAfterVerification: true, // Auto sign in after verification
          expiresIn: 60 * 60, // 1 hour
        }
      : undefined,
    user: {
      modelName: 'auth_user',
      additionalFields: {
        // Add any custom user fields here
      },
    },
    session: {
      modelName: 'auth_session',
      expiresIn: 60 * 60 * 24 * 7, // 7 days
      updateAge: 60 * 60 * 24, // 1 day
      cookieCache: {
        enabled: true,
      },
    },
    account: {
      modelName: 'auth_account',
    },
    verification: {
      modelName: 'auth_verification',
    },
    databaseHooks: onUserCreated
      ? {
          user: {
            create: {
              after: onUserCreated,
            },
          },
        }
      : undefined,
    // You can add social providers here
    // socialProviders: {
    //   google: {
    //     clientId: process.env.GOOGLE_CLIENT_ID,
    //     clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    //   },
    // },
  });
}

export type Auth = AuthInstance;
