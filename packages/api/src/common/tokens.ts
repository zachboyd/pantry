/**
 * Centralized dependency injection tokens for the application
 * Using a map structure to organize tokens by domain and prevent conflicts
 */

export const TOKENS = {
  // Database related tokens
  DATABASE: {
    CONNECTION: 'DATABASE_CONNECTION',
    SERVICE: 'DATABASE_SERVICE',
  },

  // Auth related tokens
  AUTH: {
    SERVICE: 'AUTH_SERVICE',
    GUARD: 'AUTH_GUARD',
    FACTORY: 'AUTH_FACTORY',
    AUTH_SYNC_SERVICE: 'AUTH_SYNC_SERVICE',
  },

  // Config related tokens
  CONFIG: {
    SERVICE: 'CONFIG_SERVICE',
  },

  // PowerSync related tokens
  POWERSYNC: {
    SERVICE: 'POWERSYNC_SERVICE',
    AUTH_SERVICE: 'POWERSYNC_AUTH_SERVICE',
    OPERATION_SERVICE: 'POWERSYNC_OPERATION_SERVICE',
  },

  // User related tokens
  USER: {
    SERVICE: 'USER_SERVICE',
    REPOSITORY: 'USER_REPOSITORY',
  },

  // Message related tokens
  MESSAGE: {
    SERVICE: 'MESSAGE_SERVICE',
    REPOSITORY: 'MESSAGE_REPOSITORY',
    TYPING_INDICATOR_SERVICE: 'TYPING_INDICATOR_SERVICE',
    TYPING_INDICATOR_REPOSITORY: 'TYPING_INDICATOR_REPOSITORY',
  },

  // Worker related tokens
  WORKER: {
    SERVICE: 'WORKER_SERVICE',
    COORDINATOR: 'WORKER_COORDINATOR',
    HATCHET_CLIENT: 'HATCHET_CLIENT',
  },

  // Health related tokens
  HEALTH: {
    SERVICE: 'HEALTH_SERVICE',
  },
} as const;

// Type helpers for better type safety
export type TokenMap = typeof TOKENS;
export type DatabaseTokens = typeof TOKENS.DATABASE;
export type AuthTokens = typeof TOKENS.AUTH;
export type ConfigTokens = typeof TOKENS.CONFIG;
export type MessageTokens = typeof TOKENS.MESSAGE;
export type WorkerTokens = typeof TOKENS.WORKER;
export type HealthTokens = typeof TOKENS.HEALTH;
