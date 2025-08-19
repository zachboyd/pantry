import { config } from 'dotenv';
import { createAuth } from './modules/auth/auth.config.js';
import type { Configuration } from './modules/config/config.types.js';

//  Auth file required for generating better-auth schema. It is required to be named this and in the root of the project or src

// Load environment variables
config();

/**
 * Simple config helper for auth schema generation
 * Reads environment variables directly without NestJS dependencies
 */
function getAuthSchemaConfig(): Configuration['betterAuth'] {
  return {
    secret: process.env.BETTER_AUTH_SECRET || '',
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID || '',
      clientSecret: process.env.GOOGLE_CLIENT_SECRET || '',
    },
  };
}

export const auth: ReturnType<typeof createAuth> = createAuth({
  authConfig: getAuthSchemaConfig(),
});
