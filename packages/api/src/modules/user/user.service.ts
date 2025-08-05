import { Injectable, Logger } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import { AIPersonality } from '../../common/enums.js';
import type { User } from '../../generated/database.js';
import type { Insertable, Updateable } from 'kysely';
import type { UserService, UserRecord, UserRepository } from './user.types.js';

@Injectable()
export class UserServiceImpl implements UserService {
  private readonly logger = new Logger(UserServiceImpl.name);

  constructor(
    @Inject(TOKENS.USER.REPOSITORY)
    private readonly userRepository: UserRepository,
  ) {}

  async getUserByAuthId(authUserId: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by auth ID: ${authUserId}`);

    try {
      const user = await this.userRepository.getUserByAuthId(authUserId);

      if (!user) {
        this.logger.debug(`No user found for auth_user_id: ${authUserId}`);
        return null;
      }

      return user;
    } catch (error) {
      this.logger.error(`Error getting user by auth ID ${authUserId}:`, error);
      throw error;
    }
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by ID: ${id}`);

    try {
      const user = await this.userRepository.getUserById(id);

      if (!user) {
        this.logger.debug(`No user found for id: ${id}`);
        return null;
      }

      return user;
    } catch (error) {
      this.logger.error(`Error getting user by ID ${id}:`, error);
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
      this.logger.log(`User updated successfully: ${id}`);
      return user;
    } catch (error) {
      this.logger.error(`Error updating user ${id}:`, error);
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
      this.logger.error(`Error creating user:`, error);
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
        first_name: userData.first_name || 'Pantry',
        last_name: userData.last_name || 'Assistant',
        display_name:
          userData.display_name || `${personality} - Pantry Assistant`,
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
      this.logger.error(`Error creating AI user:`, error);
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
      this.logger.log(
        `Primary household set successfully for user ${userId}`,
      );
      return user;
    } catch (error) {
      this.logger.error(
        `Error setting primary household for user ${userId}:`,
        error,
      );
      throw error;
    }
  }
}
