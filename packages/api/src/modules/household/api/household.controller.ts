import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  Post,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { TOKENS } from '../../../common/tokens.js';
import { User } from '../../auth/auth.decorator.js';
import type { UserRecord } from '../../user/user.types.js';
import type { HouseholdRecord } from '../household.types.js';
import { HouseholdApi, CreateHouseholdInput } from './household.api.js';

@ApiTags('household')
@Controller('api/household')
export class HouseholdController {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.API)
    private readonly householdApi: HouseholdApi,
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
    @Body() body: CreateHouseholdInput,
    @User() user: UserRecord | null,
  ): Promise<HouseholdRecord> {
    const result = await this.householdApi.createHousehold(body, user);
    return result.household;
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
    const result = await this.householdApi.getHousehold(householdId, user);
    return result.household;
  }
}