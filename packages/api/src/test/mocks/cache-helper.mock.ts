import { vi } from 'vitest';
import type { CacheHelper } from '../../modules/cache/cache.helper.js';

// Define the mock type with all CacheHelper methods
export type CacheHelperMockType = CacheHelper & {
  buildKey: ReturnType<typeof vi.fn>;
  getTtl: ReturnType<typeof vi.fn>;
  getCacheConfig: ReturnType<typeof vi.fn>;
  getCacheTypes: ReturnType<typeof vi.fn>;
};

/**
 * CacheHelper mock factory for consistent testing
 */
export class CacheHelperMock {
  /**
   * Creates a mock CacheHelper instance with default behaviors
   */
  static createCacheHelperMock(): CacheHelperMockType {
    const mockCacheHelper = {
      buildKey: vi.fn((type: string, identifier: string) => {
        // Default behavior matches real implementation
        const prefixes = {
          permissions: 'permissions',
          users: 'users',
          households: 'households',
        };
        const prefix = prefixes[type as keyof typeof prefixes] || type;
        return `${prefix}:${identifier}`;
      }),

      getTtl: vi.fn((type: string) => {
        // Default TTLs match real implementation
        const ttls = {
          permissions: 300000,  // 5 minutes
          users: 600000,        // 10 minutes
          households: 1800000,  // 30 minutes
        };
        return ttls[type as keyof typeof ttls] || 300000; // Default to 5 minutes
      }),

      getCacheConfig: vi.fn((type: string, identifier: string) => {
        const mockHelper = mockCacheHelper as CacheHelperMockType;
        const key = mockHelper.buildKey(type, identifier);
        const ttl = mockHelper.getTtl(type);
        return { key, ttl };
      }),

      getCacheTypes: vi.fn(() => ['permissions', 'users', 'households']),
    } as CacheHelperMockType;

    return mockCacheHelper;
  }

  /**
   * Creates a CacheHelper mock with custom configurations
   */
  static createCustomCacheHelperMock(config: {
    prefixes?: Record<string, string>;
    ttls?: Record<string, number>;
    types?: string[];
  }): CacheHelperMockType {
    const { prefixes = {}, ttls = {}, types = ['permissions', 'users', 'households'] } = config;

    const defaultPrefixes = {
      permissions: 'permissions',
      users: 'users',
      households: 'households',
      ...prefixes,
    };

    const defaultTtls = {
      permissions: 300000,
      users: 600000,
      households: 1800000,
      ...ttls,
    };

    const mockCacheHelper = {
      buildKey: vi.fn((type: string, identifier: string) => {
        const prefix = defaultPrefixes[type] || type;
        return `${prefix}:${identifier}`;
      }),

      getTtl: vi.fn((type: string) => {
        return defaultTtls[type] || 300000;
      }),

      getCacheConfig: vi.fn((type: string, identifier: string) => {
        const mockHelper = mockCacheHelper as CacheHelperMockType;
        const key = mockHelper.buildKey(type, identifier);
        const ttl = mockHelper.getTtl(type);
        return { key, ttl };
      }),

      getCacheTypes: vi.fn(() => types),
    } as CacheHelperMockType;

    return mockCacheHelper;
  }

  /**
   * Creates a CacheHelper mock that throws errors for testing error scenarios
   */
  static createErrorCacheHelperMock(error: Error = new Error('CacheHelper error')): CacheHelperMockType {
    const mockCacheHelper = {
      buildKey: vi.fn().mockImplementation(() => {
        throw error;
      }),
      getTtl: vi.fn().mockImplementation(() => {
        throw error;
      }),
      getCacheConfig: vi.fn().mockImplementation(() => {
        throw error;
      }),
      getCacheTypes: vi.fn().mockImplementation(() => {
        throw error;
      }),
    } as CacheHelperMockType;

    return mockCacheHelper;
  }

  /**
   * Resets all mocks on a CacheHelper instance
   */
  static resetMocks(cacheHelper: CacheHelperMockType) {
    cacheHelper.buildKey.mockReset();
    cacheHelper.getTtl.mockReset();
    cacheHelper.getCacheConfig.mockReset();
    cacheHelper.getCacheTypes.mockReset();
  }

  /**
   * Configures a CacheHelper mock for specific cache types and behaviors
   */
  static configureMockBehavior(
    mock: CacheHelperMockType,
    behaviors: {
      buildKey?: (type: string, identifier: string) => string;
      getTtl?: (type: string) => number;
      getCacheConfig?: (type: string, identifier: string) => { key: string; ttl: number };
      getCacheTypes?: () => string[];
    }
  ) {
    if (behaviors.buildKey) {
      mock.buildKey.mockImplementation(behaviors.buildKey);
    }
    if (behaviors.getTtl) {
      mock.getTtl.mockImplementation(behaviors.getTtl);
    }
    if (behaviors.getCacheConfig) {
      mock.getCacheConfig.mockImplementation(behaviors.getCacheConfig);
    }
    if (behaviors.getCacheTypes) {
      mock.getCacheTypes.mockImplementation(behaviors.getCacheTypes);
    }
  }
}