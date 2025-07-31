import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable, Updateable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { HouseholdRole } from '../../common/enums.js';
import { TOKENS } from '../../common/tokens.js';
import type { User } from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type { UserRecord, UserRepository } from './user.types.js';

@Injectable()
export class UserRepositoryImpl implements UserRepository {
  private readonly logger = new Logger(UserRepositoryImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
  ) {}

  async getUserByAuthId(authUserId: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by auth ID: ${authUserId}`);

    const db = this.databaseService.getConnection();

    try {
      const user = await db
        .selectFrom('user')
        .selectAll()
        .where('auth_user_id', '=', authUserId)
        .executeTakeFirst();

      if (!user) {
        this.logger.debug(`No user found for auth_user_id: ${authUserId}`);
        return null;
      }

      return user as UserRecord;
    } catch (error) {
      this.logger.error(`Failed to get user by auth ID ${authUserId}:`, error);
      throw error;
    }
  }

  async getUserById(id: string): Promise<UserRecord | null> {
    this.logger.log(`Getting user by ID: ${id}`);

    const db = this.databaseService.getConnection();

    try {
      const user = await db
        .selectFrom('user')
        .selectAll()
        .where('id', '=', id)
        .executeTakeFirst();

      if (!user) {
        this.logger.debug(`No user found for id: ${id}`);
        return null;
      }

      return user as UserRecord;
    } catch (error) {
      this.logger.error(`Failed to get user by ID ${id}:`, error);
      throw error;
    }
  }

  async updateUser(
    id: string,
    userData: Updateable<User>,
  ): Promise<UserRecord> {
    this.logger.log(`Updating user: ${id}`);

    const db = this.databaseService.getConnection();

    try {
      const [updatedUser] = await db
        .updateTable('user')
        .set({
          ...userData,
          updated_at: new Date(),
        })
        .where('id', '=', id)
        .returningAll()
        .execute();

      this.logger.log(`User updated successfully: ${id}`);
      return updatedUser as UserRecord;
    } catch (error) {
      this.logger.error(`Failed to update user ${id}:`, error);
      throw error;
    }
  }

  async createUser(userData: Insertable<User>): Promise<UserRecord> {
    this.logger.log(`Creating user: ${userData.email || 'no email'}`);

    const db = this.databaseService.getConnection();

    try {
      const [createdUser] = await db
        .insertInto('user')
        .values({
          id: userData.id || uuidv4(),
          first_name: userData.first_name,
          last_name: userData.last_name,
          email: userData.email,
          auth_user_id: userData.auth_user_id,
          display_name: userData.display_name,
          avatar_url: userData.avatar_url,
          phone: userData.phone,
          birth_date: userData.birth_date,
          preferences: userData.preferences,
          managed_by: userData.managed_by,
          relationship_to_manager: userData.relationship_to_manager,
          ...(userData.created_at && { created_at: userData.created_at }),
          ...(userData.updated_at && { updated_at: userData.updated_at }),
        })
        .returningAll()
        .execute();

      this.logger.log(`User created successfully: ${createdUser.id}`);
      return createdUser as UserRecord;
    } catch (error) {
      this.logger.error(`Failed to create user:`, error);
      throw error;
    }
  }

  async findHouseholdAIUser(householdId: string): Promise<UserRecord | null> {
    this.logger.log(`Finding AI user for household: ${householdId}`);

    const db = this.databaseService.getConnection();

    try {
      // Find AI user by querying household_member with role='ai'
      const aiUser = await db
        .selectFrom('user')
        .innerJoin('household_member', 'user.id', 'household_member.user_id')
        .selectAll('user')
        .where('household_member.household_id', '=', householdId)
        .where('household_member.role', '=', HouseholdRole.AI)
        .executeTakeFirst();

      if (!aiUser) {
        this.logger.warn(`No AI user found for household: ${householdId}`);
        return null;
      }

      this.logger.debug(
        `Found AI user ${aiUser.id} for household ${householdId}`,
      );
      return aiUser as UserRecord;
    } catch (error) {
      this.logger.error(
        `Failed to find AI user for household ${householdId}:`,
        error,
      );
      throw error;
    }
  }
}
