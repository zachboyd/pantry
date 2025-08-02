import { vi } from 'vitest';
import type { Cache } from 'cache-manager';

// Define the mock type with commonly used cache-manager methods
export type CacheManagerMockType = Cache & {
  wrap: ReturnType<typeof vi.fn>;
  get: ReturnType<typeof vi.fn>;
  set: ReturnType<typeof vi.fn>;
  del: ReturnType<typeof vi.fn>;
  reset: ReturnType<typeof vi.fn>;
  store: ReturnType<typeof vi.fn>;
  mget: ReturnType<typeof vi.fn>;
  mset: ReturnType<typeof vi.fn>;
  mdel: ReturnType<typeof vi.fn>;
};

/**
 * Cache-manager mock factory for consistent testing
 */
export class CacheManagerMock {
  /**
   * Creates a mock Cache instance for testing with standard behavior
   * By default, wrap() calls the function directly (no caching in tests)
   */
  static createCacheManagerMock(): CacheManagerMockType {
    const mockCache = {
      // Core caching methods
      get: vi.fn(),
      set: vi.fn(),
      del: vi.fn(),
      reset: vi.fn(),

      // Wrap method - calls function directly by default for testing
      wrap: vi.fn(async <T>(key: string, fn: () => T, _ttl?: number) => {
        return fn();
      }),

      // Multi-key operations
      mget: vi.fn(),
      mset: vi.fn(),
      mdel: vi.fn(),

      // Store access
      store: vi.fn(),
    } as CacheManagerMockType;

    return mockCache;
  }

  /**
   * Creates a cache mock that actually stores values for testing cache behavior
   */
  static createMemoryCacheMock(): CacheManagerMockType {
    const storage = new Map<string, { value: unknown; expires?: number }>();

    const mockCache = {
      get: vi.fn(async (key: string) => {
        const item = storage.get(key);
        if (!item) return undefined;
        if (item.expires && Date.now() > item.expires) {
          storage.delete(key);
          return undefined;
        }
        return item.value;
      }),

      set: vi.fn(async (key: string, value: unknown, ttl?: number) => {
        const expires = ttl ? Date.now() + ttl : undefined;
        storage.set(key, { value, expires });
      }),

      del: vi.fn(async (key: string) => {
        return storage.delete(key);
      }),

      reset: vi.fn(async () => {
        storage.clear();
      }),

      wrap: vi.fn(async <T>(key: string, fn: () => T, ttl?: number) => {
        const cached = await mockCache.get(key);
        if (cached !== undefined) {
          return cached;
        }
        const result = await fn();
        await mockCache.set(key, result, ttl);
        return result;
      }),

      // Multi-key operations
      mget: vi.fn(async (keys: string[]) => {
        const results = await Promise.all(keys.map(key => mockCache.get(key)));
        return results;
      }),

      mset: vi.fn(async (keyValuePairs: Array<[string, unknown]>, ttl?: number) => {
        await Promise.all(
          keyValuePairs.map(([key, value]) => mockCache.set(key, value, ttl))
        );
      }),

      mdel: vi.fn(async (keys: string[]) => {
        const results = await Promise.all(keys.map(key => mockCache.del(key)));
        return results;
      }),

      store: vi.fn(),
    } as CacheManagerMockType;

    return mockCache;
  }

  /**
   * Creates a cache mock that always throws errors for testing error scenarios
   */
  static createErrorCacheMock(error: Error = new Error('Cache error')): CacheManagerMockType {
    const mockCache = {
      get: vi.fn().mockRejectedValue(error),
      set: vi.fn().mockRejectedValue(error),
      del: vi.fn().mockRejectedValue(error),
      reset: vi.fn().mockRejectedValue(error),
      wrap: vi.fn().mockRejectedValue(error),
      mget: vi.fn().mockRejectedValue(error),
      mset: vi.fn().mockRejectedValue(error),
      mdel: vi.fn().mockRejectedValue(error),
      store: vi.fn(),
    } as CacheManagerMockType;

    return mockCache;
  }

  /**
   * Resets all mocks on a cache instance
   */
  static resetMocks(cache: CacheManagerMockType) {
    cache.get.mockReset();
    cache.set.mockReset();
    cache.del.mockReset();
    cache.reset.mockReset();
    cache.wrap.mockReset();
    cache.mget.mockReset();
    cache.mset.mockReset();
    cache.mdel.mockReset();
  }
}