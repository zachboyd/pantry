import { config } from 'dotenv';
import { createAuth } from './modules/auth/auth.config.js';

//  Auth file required for generating better-auth schema. It is required to be named this and in the root of the project or src

// Load environment variables
config();

export const auth: ReturnType<typeof createAuth> = createAuth();
