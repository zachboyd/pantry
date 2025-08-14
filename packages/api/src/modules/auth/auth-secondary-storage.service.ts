import { Injectable, Inject, Logger } from '@nestjs/common';
import type { Cache } from 'cache-manager';
import { TOKENS } from '../../common/tokens.js';

/**
 * Better Auth SecondaryStorage interface
 */
export interface SecondaryStorage {
  get: (key: string) => Promise<string | null>;
  set: (key: string, value: string, ttl?: number) => Promise<void>;
  delete: (key: string) => Promise<void>;
}

/**
 * Redis-based secondary storage implementation for Better Auth
 * Uses existing Redis cache infrastructure for session storage
 */
@Injectable()
export class AuthSecondaryStorageService implements SecondaryStorage {
  private readonly logger = new Logger(AuthSecondaryStorageService.name);

  constructor(
    @Inject(TOKENS.CACHE.MANAGER)
    private readonly cacheManager: Cache,
  ) {}

  /**
   * Get value from Redis cache
   */
  async get(key: string): Promise<string | null> {
    try {
      const value = await this.cacheManager.get<string>(key);
      return value || null;
    } catch (error) {
      this.logger.error(`Redis get error for key ${key}:`, error);
      return null;
    }
  }

  /**
   * Set value in Redis cache with optional TTL
   */
  async set(key: string, value: string, ttl?: number): Promise<void> {
    try {
      if (ttl) {
        // TTL in seconds
        await this.cacheManager.set(key, value, ttl * 1000); // cache-manager expects milliseconds
      } else {
        await this.cacheManager.set(key, value);
      }
    } catch (error) {
      this.logger.error(`Redis set error for key ${key}:`, error);
      throw error;
    }
  }

  /**
   * Delete value from Redis cache
   */
  async delete(key: string): Promise<void> {
    try {
      await this.cacheManager.del(key);
    } catch (error) {
      this.logger.error(`Redis delete error for key ${key}:`, error);
      throw error;
    }
  }
}
