import { Injectable, Logger } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import type { Cache } from 'cache-manager';
import { TOKENS } from '../../common/tokens.js';
import { AIPersonality } from '../../common/enums.js';
import type { User } from '../../generated/database.js';
import type { Insertable, Updateable } from 'kysely';
import type { UserService, UserRecord, UserRepository } from './user.types.js';
import type { PubSubService } from '../pubsub/pubsub.types.js';
import type { CacheHelper } from '../cache/cache.helper.js';

@Injectable()
export class UserServiceImpl implements UserService {
  private readonly logger = new Logger(UserServiceImpl.name);

  constructor(
    @Inject(TOKENS.USER.REPOSITORY)
    private readonly userRepository: UserRepository,
    @Inject(TOKENS.PUBSUB.SERVICE)
    private readonly pubsubService: PubSubService,
    @Inject(TOKENS.CACHE.MANAGER)
    private readonly cache: Cache,
    @Inject(TOKENS.CACHE.HELPER)
    private readonly cacheHelper: CacheHelper,
  ) {}

  async getUserByAuthId(authUserId: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by auth ID: ${authUserId}`);

    const { key, ttl } = this.cacheHelper.getCacheConfig(
      'users',
      `auth:${authUserId}`,
    );

    try {
      // Try to get from cache first
      const cachedUser = await this.cache.get<UserRecord | null>(key);
      if (cachedUser !== undefined) {
        this.logger.debug(`Cache hit for auth_user_id: ${authUserId}`);
        return cachedUser;
      }

      // Cache miss - get from database
      const user = await this.userRepository.getUserByAuthId(authUserId);

      // Cache the result (including null results to avoid repeated DB queries)
      await this.cache.set(key, user, ttl);

      if (!user) {
        this.logger.debug(`No user found for auth_user_id: ${authUserId}`);
        return null;
      }

      return user;
    } catch (error) {
      this.logger.error(error, `Error getting user by auth ID ${authUserId}:`);
      throw error;
    }
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by ID: ${id}`);

    const { key, ttl } = this.cacheHelper.getCacheConfig('users', `id:${id}`);

    try {
      // Try to get from cache first
      const cachedUser = await this.cache.get<UserRecord | null>(key);
      if (cachedUser !== undefined) {
        this.logger.debug(`Cache hit for user_id: ${id}`);
        return cachedUser;
      }

      // Cache miss - get from database
      const user = await this.userRepository.getUserById(id);

      // Cache the result (including null results to avoid repeated DB queries)
      await this.cache.set(key, user, ttl);

      if (!user) {
        this.logger.debug(`No user found for id: ${id}`);
        return null;
      }

      return user;
    } catch (error) {
      this.logger.error(error, `Error getting user by ID ${id}:`);
      throw error;
    }
  }

  async updateUser(
    id: string,
    userData: Updateable<User>,
  ): Promise<UserRecord> {
    this.logger.log(`Updating user: ${id}`);

    try {
      const user = await this.userRepository.updateUser(id, userData);

      // Call centralized post-update hook
      await this.afterUserUpdated(id, user);

      this.logger.log(`User updated successfully: ${id}`);
      return user;
    } catch (error) {
      this.logger.error(error, `Error updating user ${id}:`);
      throw error;
    }
  }

  async createUser(userData: Insertable<User>): Promise<UserRecord> {
    this.logger.log(
      `Creating user: ${userData.display_name || userData.first_name}`,
    );

    try {
      const user = await this.userRepository.createUser(userData);
      this.logger.log(`User created successfully: ${user.id}`);
      return user;
    } catch (error) {
      this.logger.error(error, `Error creating user:`);
      throw error;
    }
  }

  async createAIUser(userData: Insertable<User>): Promise<UserRecord> {
    this.logger.log(
      `Creating AI user: ${userData.display_name || userData.first_name}`,
    );

    try {
      // Generate random personality if not provided
      const personalities = Object.values(AIPersonality);
      const personality =
        personalities[Math.floor(Math.random() * personalities.length)];

      const aiUserData: Insertable<User> = {
        id: userData.id || uuidv4(),
        auth_user_id: null, // AI users don't have auth
        email: userData.email,
        first_name: userData.first_name || 'Jeeves',
        last_name: userData.last_name || 'Assistant',
        display_name:
          userData.display_name || `${personality} - Jeeves Assistant`,
        avatar_url: userData.avatar_url || '/avatars/default-ai-assistant.png',
        phone: userData.phone,
        birth_date: userData.birth_date,
        is_ai: true, // Explicitly mark as AI user
        preferences: userData.preferences || {
          personality: personality,
        },
        managed_by: userData.managed_by,
        relationship_to_manager: userData.relationship_to_manager,
        created_at: userData.created_at,
        updated_at: userData.updated_at,
      };

      const aiUser = await this.userRepository.createUser(aiUserData);
      this.logger.log(`AI user created successfully: ${aiUser.id}`);
      return aiUser;
    } catch (error) {
      this.logger.error(error, `Error creating AI user:`);
      throw error;
    }
  }

  async setPrimaryHousehold(
    userId: string,
    householdId: string,
  ): Promise<UserRecord> {
    this.logger.log(
      `Setting primary household ${householdId} for user ${userId}`,
    );

    try {
      const user = await this.userRepository.updateUser(userId, {
        primary_household_id: householdId,
      });

      // Call centralized post-update hook
      await this.afterUserUpdated(userId, user);

      this.logger.log(`Primary household set successfully for user ${userId}`);
      return user;
    } catch (error) {
      this.logger.error(
        `Error setting primary household for user ${userId}:`,
        error,
      );
      throw error;
    }
  }

  /**
   * Centralized hook for post-update logic
   * Handles event emission and any other side effects after user updates
   */
  private async afterUserUpdated(
    userId: string,
    user: UserRecord,
  ): Promise<void> {
    try {
      // Invalidate user cache entries
      await this.invalidateUserCache(userId, user.auth_user_id);

      // Emit subscription event
      await this.pubsubService.publishUserUpdated(userId, user);

      this.logger.debug(`Post-update processing completed for user ${userId}`);
    } catch (error) {
      // Don't fail the main operation if post-update logic fails
      this.logger.warn(
        `Post-update processing failed for user ${userId}:`,
        error,
      );
    }
  }

  /**
   * Invalidate cache entries for a user
   * Clears both getUserById and getUserByAuthId caches
   */
  private async invalidateUserCache(
    userId: string,
    authUserId: string,
  ): Promise<void> {
    try {
      // Invalidate getUserById cache
      const userIdCacheConfig = this.cacheHelper.getCacheConfig(
        'users',
        `id:${userId}`,
      );
      await this.cache.del(userIdCacheConfig.key);

      // Invalidate getUserByAuthId cache
      const authIdCacheConfig = this.cacheHelper.getCacheConfig(
        'users',
        `auth:${authUserId}`,
      );
      await this.cache.del(authIdCacheConfig.key);

      this.logger.debug(`Cache invalidated for user ${userId}`);
    } catch (error) {
      this.logger.warn(error, `Failed to invalidate cache for user ${userId}:`);
      // Don't throw - cache invalidation failures shouldn't break user updates
    }
  }
}
