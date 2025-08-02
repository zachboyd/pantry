import { Injectable } from '@nestjs/common';

/**
 * Simple helper service for cache key construction and TTL management
 */
@Injectable()
export class CacheHelper {
  private readonly config = {
    permissions: {
      ttl: 300000, // 5 minutes
      prefix: 'permissions',
    },
    users: {
      ttl: 600000, // 10 minutes
      prefix: 'users',
    },
    households: {
      ttl: 1800000, // 30 minutes
      prefix: 'households',
    },
  } as const;

  /**
   * Build a cache key with proper prefix for the given type
   * @param type Cache type (permissions, users, households)
   * @param identifier Unique identifier
   * @returns Formatted cache key
   */
  buildKey(type: keyof typeof this.config, identifier: string): string {
    return `${this.config[type].prefix}:${identifier}`;
  }

  /**
   * Get TTL for specific cache type
   * @param type Cache type
   * @returns TTL in milliseconds
   */
  getTtl(type: keyof typeof this.config): number {
    return this.config[type].ttl;
  }

  /**
   * Get cache configuration (key and TTL) for the given type and identifier
   * @param type Cache type (permissions, users, households)
   * @param identifier Unique identifier
   * @returns Object with cache key and TTL
   */
  getCacheConfig(
    type: keyof typeof this.config,
    identifier: string,
  ): { key: string; ttl: number } {
    return {
      key: `${this.config[type].prefix}:${identifier}`,
      ttl: this.config[type].ttl,
    };
  }

  /**
   * Get all available cache types
   */
  getCacheTypes(): Array<keyof typeof this.config> {
    return Object.keys(this.config) as Array<keyof typeof this.config>;
  }
}
