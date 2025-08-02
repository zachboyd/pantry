import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import type {
  Household,
  HouseholdMember,
  HouseholdRole,
} from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type {
  HouseholdRepository,
  HouseholdRecord,
  HouseholdMemberRecord,
} from './household.types.js';

@Injectable()
export class HouseholdRepositoryImpl implements HouseholdRepository {
  private readonly logger = new Logger(HouseholdRepositoryImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
  ) {}

  async createHousehold(
    household: Insertable<Household>,
  ): Promise<HouseholdRecord> {
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

  async addHouseholdMember(
    member: Insertable<HouseholdMember>,
  ): Promise<HouseholdMemberRecord> {
    this.logger.log(
      `Adding member ${member.user_id} to household ${member.household_id} with role ${member.role}`,
    );

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

      this.logger.log(
        `Household member created successfully: ${createdMember.id}`,
      );
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

  async getHouseholdByIdForUser(
    householdId: string,
    userId: string,
  ): Promise<HouseholdRecord | null> {
    this.logger.log(`Getting household ${householdId} for user ${userId}`);

    const db = this.databaseService.getConnection();

    try {
      const household = await db
        .selectFrom('household')
        .innerJoin(
          'household_member',
          'household.id',
          'household_member.household_id',
        )
        .selectAll('household')
        .where('household.id', '=', householdId)
        .where('household_member.user_id', '=', userId)
        .executeTakeFirst();

      if (!household) {
        this.logger.debug(
          `No household found for ID ${householdId} and user ${userId}`,
        );
        return null;
      }

      return household as HouseholdRecord;
    } catch (error) {
      this.logger.error(
        `Failed to get household ${householdId} for user ${userId}:`,
        error,
      );
      throw error;
    }
  }

  async getHouseholdsForUser(userId: string): Promise<HouseholdRecord[]> {
    this.logger.log(`Getting households for user: ${userId}`);

    const db = this.databaseService.getConnection();

    try {
      const households = await db
        .selectFrom('household')
        .innerJoin(
          'household_member',
          'household.id',
          'household_member.household_id',
        )
        .selectAll('household')
        .where('household_member.user_id', '=', userId)
        .execute();

      this.logger.debug(
        `Retrieved ${households.length} households for user ${userId}`,
      );
      return households as HouseholdRecord[];
    } catch (error) {
      this.logger.error(`Failed to get households for user ${userId}:`, error);
      return [];
    }
  }

  async removeHouseholdMember(
    householdId: string,
    userId: string,
  ): Promise<HouseholdMemberRecord | null> {
    this.logger.log(`Removing member ${userId} from household ${householdId}`);

    const db = this.databaseService.getConnection();

    try {
      const [removedMember] = await db
        .deleteFrom('household_member')
        .where('household_id', '=', householdId)
        .where('user_id', '=', userId)
        .returningAll()
        .execute();

      if (!removedMember) {
        this.logger.debug(
          `No household member found for household ${householdId} and user ${userId}`,
        );
        return null;
      }

      this.logger.log(
        `Household member removed successfully: ${removedMember.id}`,
      );
      return removedMember as HouseholdMemberRecord;
    } catch (error) {
      this.logger.error(`Failed to remove household member:`, error);
      throw error;
    }
  }

  async getHouseholdMember(
    householdId: string,
    userId: string,
  ): Promise<HouseholdMemberRecord | null> {
    this.logger.log(
      `Getting household member for household ${householdId} and user ${userId}`,
    );

    const db = this.databaseService.getConnection();

    try {
      const member = await db
        .selectFrom('household_member')
        .selectAll()
        .where('household_id', '=', householdId)
        .where('user_id', '=', userId)
        .executeTakeFirst();

      if (!member) {
        this.logger.debug(
          `No household member found for household ${householdId} and user ${userId}`,
        );
        return null;
      }

      return member as HouseholdMemberRecord;
    } catch (error) {
      this.logger.error(`Failed to get household member:`, error);
      throw error;
    }
  }

  async getHouseholdMembers(
    householdId: string,
  ): Promise<HouseholdMemberRecord[]> {
    this.logger.log(`Getting all members for household ${householdId}`);

    const db = this.databaseService.getConnection();

    try {
      const members = await db
        .selectFrom('household_member')
        .selectAll()
        .where('household_id', '=', householdId)
        .execute();

      this.logger.debug(
        `Retrieved ${members.length} members for household ${householdId}`,
      );
      return members as HouseholdMemberRecord[];
    } catch (error) {
      this.logger.error(`Failed to get household members:`, error);
      return [];
    }
  }

  async updateHouseholdMemberRole(
    householdId: string,
    userId: string,
    newRole: string,
  ): Promise<HouseholdMemberRecord | null> {
    this.logger.log(
      `Updating member ${userId} role to ${newRole} in household ${householdId}`,
    );

    const db = this.databaseService.getConnection();

    try {
      const [updatedMember] = await db
        .updateTable('household_member')
        .set({ role: newRole as HouseholdRole })
        .where('household_id', '=', householdId)
        .where('user_id', '=', userId)
        .returningAll()
        .execute();

      if (!updatedMember) {
        this.logger.debug(
          `No household member found to update for household ${householdId} and user ${userId}`,
        );
        return null;
      }

      this.logger.log(
        `Household member role updated successfully: ${updatedMember.id}`,
      );
      return updatedMember as HouseholdMemberRecord;
    } catch (error) {
      this.logger.error(`Failed to update household member role:`, error);
      throw error;
    }
  }
}
