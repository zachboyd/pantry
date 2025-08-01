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

  // Household related tokens
  HOUSEHOLD: {
    SERVICE: 'HOUSEHOLD_SERVICE',
    REPOSITORY: 'HOUSEHOLD_REPOSITORY',
    GUARDED_SERVICE: 'HOUSEHOLD_GUARDED_SERVICE',
  },

  // Attachment related tokens
  ATTACHMENT: {
    SERVICE: 'ATTACHMENT_SERVICE',
    REPOSITORY: 'ATTACHMENT_REPOSITORY',
  },

  // Storage related tokens
  STORAGE: {
    SERVICE: 'STORAGE_SERVICE',
    FACTORY: 'STORAGE_FACTORY',
    S3_IMPL: 'STORAGE_S3_IMPLEMENTATION',
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

  // Permission related tokens
  PERMISSION: {
    SERVICE: 'PERMISSION_SERVICE',
  },

  // Cache related tokens
  CACHE: {
    MANAGER: 'CACHE_MANAGER',
    HELPER: 'CACHE_HELPER',
    REDIS_CLIENT: 'REDIS_CLIENT',
  },
} as const;

// Type helpers for better type safety
export type TokenMap = typeof TOKENS;
export type DatabaseTokens = typeof TOKENS.DATABASE;
export type AuthTokens = typeof TOKENS.AUTH;
export type ConfigTokens = typeof TOKENS.CONFIG;
export type MessageTokens = typeof TOKENS.MESSAGE;
export type HouseholdTokens = typeof TOKENS.HOUSEHOLD;
export type AttachmentTokens = typeof TOKENS.ATTACHMENT;
export type StorageTokens = typeof TOKENS.STORAGE;
export type WorkerTokens = typeof TOKENS.WORKER;
export type HealthTokens = typeof TOKENS.HEALTH;
export type PermissionTokens = typeof TOKENS.PERMISSION;
export type CacheTokens = typeof TOKENS.CACHE;
