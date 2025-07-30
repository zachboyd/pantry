import { betterAuth } from 'better-auth';
import { PostgresDialect } from 'kysely';
import { Pool } from 'pg';

import type { BetterAuthUser } from './auth.types.js';

type AuthInstance = ReturnType<typeof betterAuth>;
type UserCreatedCallback = (user: BetterAuthUser) => Promise<void>;

export function createAuth(onUserCreated?: UserCreatedCallback): AuthInstance {
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
      cookiePrefix: 'pantry',
    },
    emailAndPassword: {
      enabled: true,
      requireEmailVerification:
        process.env.BETTER_AUTH_REQUIRE_EMAIL_VERIFICATION === 'true',
    },
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
