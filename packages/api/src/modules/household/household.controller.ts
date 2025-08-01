import {
  Body,
  Controller,
  Get,
  Inject,
  Logger,
  Param,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../common/tokens.js';
import { User } from '../auth/auth.decorator.js';
import type { UserRecord } from '../user/user.types.js';
import type {
  HouseholdRecord,
  HouseholdService,
} from './household.types.js';

@ApiTags('household')
@Controller('api/household')
export class HouseholdController {
  private readonly logger = new Logger(HouseholdController.name);

  constructor(
    @Inject(TOKENS.HOUSEHOLD.SERVICE)
    private readonly householdService: HouseholdService,
  ) {}

  @Post()
  @ApiOperation({ summary: 'Create a new household' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 201,
    description: 'Household created successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        name: { type: 'string' },
        description: { type: 'string' },
        created_by: { type: 'string' },
        created_at: { type: 'string' },
        updated_at: { type: 'string' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  async createHousehold(
    @Body() body: { name: string; description?: string },
    @User() user: UserRecord | null,
  ): Promise<HouseholdRecord> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(
        `Creating household: ${body.name} for user ${user.id}`,
      );

      const household = await this.householdService.createHousehold(
        {
          id: uuidv4(),
          name: body.name,
          description: body.description || null,
          created_by: user.id,
        },
        user.id,
      );

      this.logger.log(`Created household: ${household.id}`);

      return household;
    } catch (error) {
      this.logger.error(error, 'Failed to create household');
      throw error;
    }
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get household by ID' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Household retrieved successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({ status: 404, description: 'Household not found' })
  async getHousehold(
    @Param('id') householdId: string,
    @User() user: UserRecord | null,
  ): Promise<HouseholdRecord> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(
        `Getting household: ${householdId} for user ${user.id}`,
      );

      const household = await this.householdService.getHouseholdById(householdId, user.id);
      return household;
    } catch (error) {
      this.logger.error(error, 'Failed to get household');
      throw error;
    }
  }
}