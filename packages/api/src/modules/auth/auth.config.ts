import { betterAuth } from 'better-auth';
import { PostgresDialect } from 'kysely';
import { Pool } from 'pg';

import type { BetterAuthUser } from './auth.types.js';
import type { SecondaryStorage } from './auth-secondary-storage.service.js';

type AuthInstance = ReturnType<typeof betterAuth>;
type UserCreatedCallback = (user: BetterAuthUser) => Promise<void>;
type UserUpdatedCallback = (user: BetterAuthUser) => Promise<void>;
type EmailVerificationCallback = (data: {
  user: BetterAuthUser;
  url: string;
  token: string;
}) => Promise<void>;
type EmailChangeVerificationCallback = (data: {
  user: BetterAuthUser;
  newEmail: string;
  url: string;
  token: string;
}) => Promise<void>;

export interface CreateAuthOptions {
  onUserCreated?: UserCreatedCallback;
  onUserUpdated?: UserUpdatedCallback;
  onEmailVerification?: EmailVerificationCallback;
  onEmailChangeVerification?: EmailChangeVerificationCallback;
  secondaryStorage?: SecondaryStorage;
  apiUrl?: string;
  secret?: string;
}

export function createAuth(options: CreateAuthOptions = {}): AuthInstance {
  const {
    onUserCreated,
    onUserUpdated,
    onEmailVerification,
    onEmailChangeVerification,
    secondaryStorage,
    apiUrl,
    secret,
  } = options;
  return betterAuth({
    database: {
      dialect: new PostgresDialect({
        pool: new Pool({
          connectionString: process.env.DATABASE_URL,
        }),
      }),
      provider: 'pg',
    },
    secondaryStorage,
    secret: secret || '',
    baseURL: apiUrl,
    basePath: '/api/auth',
    advanced: {
      cookiePrefix: 'jeeves',
    },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification: false, // Allow login without verification
    },
    emailVerification: onEmailVerification
      ? {
          sendVerificationEmail: async ({ user, url, token }) => {
            await onEmailVerification({ user, url, token });
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
      changeEmail: onEmailChangeVerification
        ? {
            enabled: true,
            sendChangeEmailVerification: async ({
              user,
              newEmail,
              url,
              token,
            }) => {
              await onEmailChangeVerification({ user, newEmail, url, token });
            },
          }
        : undefined,
    },
    session: {
      modelName: 'auth_session',
      expiresIn: 60 * 60 * 24 * 7, // 7 days
      updateAge: 60 * 60 * 24, // 1 day
      cookieCache: {
        enabled: false, // Disabled since we will use redis for session caching
      },
    },
    account: {
      modelName: 'auth_account',
    },
    verification: {
      modelName: 'auth_verification',
    },
    databaseHooks:
      onUserCreated || onUserUpdated
        ? {
            user: {
              ...(onUserCreated && {
                create: {
                  after: onUserCreated,
                },
              }),
              ...(onUserUpdated && {
                update: {
                  after: onUserUpdated,
                },
              }),
            },
          }
        : undefined,
  });
}

export type Auth = AuthInstance;
