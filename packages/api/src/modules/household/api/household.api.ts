import { Injectable, Inject, Logger, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../../user/user.types.js';
import type {
  HouseholdRecord,
  HouseholdService,
} from '../household.types.js';

// Input DTOs for API operations
export interface CreateHouseholdInput {
  name: string;
  description?: string;
}

export interface CreateHouseholdResponse {
  household: HouseholdRecord;
}

export interface GetHouseholdResponse {
  household: HouseholdRecord;
}

@Injectable()
export class HouseholdApi {
  private readonly logger = new Logger(HouseholdApi.name);

  constructor(
    @Inject(TOKENS.HOUSEHOLD.SERVICE)
    private readonly householdService: HouseholdService,
  ) {}

  /**
   * Create a new household for the authenticated user
   */
  async createHousehold(
    input: CreateHouseholdInput,
    user: UserRecord | null,
  ): Promise<CreateHouseholdResponse> {
    // Validation
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!input.name || input.name.trim().length === 0) {
      throw new BadRequestException('Household name is required');
    }

    if (input.name.trim().length > 100) {
      throw new BadRequestException('Household name must be 100 characters or less');
    }

    try {
      this.logger.log(`Creating household: ${input.name} for user ${user.id}`);

      const household = await this.householdService.createHousehold(
        {
          id: uuidv4(),
          name: input.name.trim(),
          description: input.description?.trim() || null,
          created_by: user.id,
        },
        user.id,
      );

      this.logger.log(`Created household: ${household.id}`);

      return { household };
    } catch (error) {
      this.logger.error(error, 'Failed to create household');
      throw error;
    }
  }

  /**
   * Get household by ID for the authenticated user
   */
  async getHousehold(
    householdId: string,
    user: UserRecord | null,
  ): Promise<GetHouseholdResponse> {
    // Validation
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!householdId || householdId.trim().length === 0) {
      throw new BadRequestException('Household ID is required');
    }

    try {
      this.logger.log(`Getting household: ${householdId} for user ${user.id}`);

      const household = await this.householdService.getHouseholdById(
        householdId.trim(),
        user.id,
      );

      return { household };
    } catch (error) {
      this.logger.error(error, 'Failed to get household');
      throw error;
    }
  }
}