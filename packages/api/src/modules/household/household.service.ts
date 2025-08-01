import { Inject, Injectable, Logger, NotFoundException, ForbiddenException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import type { Insertable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { AIPersonality, HouseholdRole } from '../../common/enums.js';
import { TOKENS } from '../../common/tokens.js';
import type { Household } from '../../generated/database.js';
import type {
  HouseholdRepository,
  HouseholdRecord,
  HouseholdService,
} from './household.types.js';

@Injectable()
export class HouseholdServiceImpl implements HouseholdService {
  private readonly logger = new Logger(HouseholdServiceImpl.name);

  constructor(
    @Inject(TOKENS.HOUSEHOLD.REPOSITORY)
    private readonly householdRepository: HouseholdRepository,
    @Inject(EventEmitter2)
    private readonly eventEmitter: EventEmitter2,
  ) {}

  async createHousehold(
    householdData: Insertable<Household>,
    creatorId: string,
  ): Promise<HouseholdRecord> {
    this.logger.log(
      `Creating household: ${householdData.name} for creator ${creatorId}`,
    );

    try {
      // 1. Create the household
      const createdHousehold = await this.householdRepository.createHousehold({
        ...householdData,
        created_by: creatorId,
      });

      this.logger.log(`Household created: ${createdHousehold.id}`);

      // 2. Add creator as household manager
      await this.householdRepository.addHouseholdMember({
        id: uuidv4(),
        household_id: createdHousehold.id,
        user_id: creatorId,
        role: HouseholdRole.MANAGER,
      });

      this.logger.log(
        `Added creator ${creatorId} as manager to household ${createdHousehold.id}`,
      );

      // 3. Create AI user for the household
      const personalities = Object.values(AIPersonality);
      const personality =
        personalities[Math.floor(Math.random() * personalities.length)];

      const aiUser = await this.householdRepository.createAIUser({
        id: uuidv4(),
        auth_user_id: null, // AI users don't have auth
        email: `ai-assistant+${createdHousehold.id}@system.internal`,
        first_name: 'Pantry',
        last_name: 'Assistant',
        display_name: `${personality} - Pantry Assistant`,
        avatar_url: '/avatars/default-ai-assistant.png',
        preferences: {
          personality: personality,
        },
      });

      this.logger.log(
        `Created AI user ${aiUser.id} for household ${createdHousehold.id}`,
      );

      // 4. Add AI user as household member with ai role
      await this.householdRepository.addHouseholdMember({
        id: uuidv4(),
        household_id: createdHousehold.id,
        user_id: aiUser.id,
        role: HouseholdRole.AI, // AI users have special ai role
      });

      this.logger.log(
        `Added AI user ${aiUser.id} as ai to household ${createdHousehold.id}`,
      );

      // 5. Emit event for downstream processing (notifications, etc.)
      this.eventEmitter.emit('household.created', {
        household: createdHousehold,
        creator: creatorId,
        aiUser: aiUser,
      });

      this.logger.log(
        `Household creation completed successfully: ${createdHousehold.id}`,
      );

      return createdHousehold;
    } catch (error) {
      this.logger.error(`Failed to create household:`, error);
      throw error;
    }
  }

  async getHouseholdById(householdId: string, userId: string): Promise<HouseholdRecord> {
    this.logger.log(`Getting household ${householdId} for user ${userId}`);

    try {
      const household = await this.householdRepository.getHouseholdByIdForUser(householdId, userId);

      if (!household) {
        this.logger.warn(`Household ${householdId} not found or user ${userId} does not have access`);
        throw new NotFoundException('Household not found');
      }

      this.logger.log(`Successfully retrieved household ${householdId} for user ${userId}`);
      return household;
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      this.logger.error(`Failed to get household ${householdId} for user ${userId}:`, error);
      throw error;
    }
  }
}
