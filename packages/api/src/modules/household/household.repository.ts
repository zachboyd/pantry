import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable, Selectable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import type { Household, HouseholdMember, User } from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type { HouseholdRepository, HouseholdRecord, HouseholdMemberRecord } from './household.types.js';

@Injectable()
export class HouseholdRepositoryImpl implements HouseholdRepository {
  private readonly logger = new Logger(HouseholdRepositoryImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
  ) {}

  async createHousehold(household: Insertable<Household>): Promise<HouseholdRecord> {
    this.logger.log(`Creating household: ${household.name}`);

    const db = this.databaseService.getConnection();

    try {
      const [createdHousehold] = await db
        .insertInto('household')
        .values({
          id: household.id || uuidv4(),
          name: household.name,
          description: household.description,
          created_by: household.created_by,
          // Let database handle timestamps if not provided
          ...(household.created_at && { created_at: household.created_at }),
          ...(household.updated_at && { updated_at: household.updated_at }),
        })
        .returningAll()
        .execute();

      this.logger.log(`Household created successfully: ${createdHousehold.id}`);
      return createdHousehold as HouseholdRecord;
    } catch (error) {
      this.logger.error(`Failed to create household:`, error);
      throw error;
    }
  }

  async addHouseholdMember(member: Insertable<HouseholdMember>): Promise<HouseholdMemberRecord> {
    this.logger.log(`Adding member ${member.user_id} to household ${member.household_id} with role ${member.role}`);

    const db = this.databaseService.getConnection();

    try {
      const [createdMember] = await db
        .insertInto('household_member')
        .values({
          id: member.id || uuidv4(),
          household_id: member.household_id,
          user_id: member.user_id,
          role: member.role || 'member',
          // Let database handle timestamps if not provided
          ...(member.joined_at && { joined_at: member.joined_at }),
        })
        .returningAll()
        .execute();

      this.logger.log(`Household member created successfully: ${createdMember.id}`);
      return createdMember as HouseholdMemberRecord;
    } catch (error) {
      this.logger.error(`Failed to add household member:`, error);
      throw error;
    }
  }

  async getHouseholdById(householdId: string): Promise<HouseholdRecord | null> {
    this.logger.log(`Getting household by ID: ${householdId}`);

    const db = this.databaseService.getConnection();

    try {
      const household = await db
        .selectFrom('household')
        .selectAll()
        .where('id', '=', householdId)
        .executeTakeFirst();

      if (!household) {
        this.logger.debug(`No household found for ID: ${householdId}`);
        return null;
      }

      return household as HouseholdRecord;
    } catch (error) {
      this.logger.error(`Failed to get household by ID ${householdId}:`, error);
      throw error;
    }
  }

  async getHouseholdsForUser(userId: string): Promise<HouseholdRecord[]> {
    this.logger.log(`Getting households for user: ${userId}`);

    const db = this.databaseService.getConnection();

    try {
      const households = await db
        .selectFrom('household')
        .innerJoin('household_member', 'household.id', 'household_member.household_id')
        .selectAll('household')
        .where('household_member.user_id', '=', userId)
        .execute();

      this.logger.debug(`Retrieved ${households.length} households for user ${userId}`);
      return households as HouseholdRecord[];
    } catch (error) {
      this.logger.error(`Failed to get households for user ${userId}:`, error);
      return [];
    }
  }

  async createAIUser(aiUser: Insertable<User>): Promise<Selectable<User>> {
    this.logger.log(`Creating AI user: ${aiUser.display_name || aiUser.first_name}`);

    const db = this.databaseService.getConnection();

    try {
      const [createdAIUser] = await db
        .insertInto('user')
        .values({
          id: aiUser.id || uuidv4(),
          auth_user_id: null, // AI users don't have auth
          email: aiUser.email,
          first_name: aiUser.first_name,
          last_name: aiUser.last_name,
          display_name: aiUser.display_name,
          avatar_url: aiUser.avatar_url,
          phone: aiUser.phone,
          birth_date: aiUser.birth_date,
          preferences: aiUser.preferences,
          managed_by: aiUser.managed_by,
          relationship_to_manager: aiUser.relationship_to_manager,
          // Let database handle timestamps if not provided
          ...(aiUser.created_at && { created_at: aiUser.created_at }),
          ...(aiUser.updated_at && { updated_at: aiUser.updated_at }),
        })
        .returningAll()
        .execute();

      this.logger.log(`AI user created successfully: ${createdAIUser.id}`);
      return createdAIUser as Selectable<User>;
    } catch (error) {
      this.logger.error(`Failed to create AI user:`, error);
      throw error;
    }
  }
}