import { Injectable, Logger } from '@nestjs/common';
import { Inject } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import type { User } from '../../generated/database.js';
import type { Updateable } from 'kysely';
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
}
