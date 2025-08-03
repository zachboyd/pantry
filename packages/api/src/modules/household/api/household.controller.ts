import {
  Body,
  Controller,
  Delete,
  Get,
  Inject,
  Param,
  Post,
  Put,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { TOKENS } from '../../../common/tokens.js';
import { CurrentUser } from '../../auth/auth.decorator.js';
import type { UserRecord } from '../../user/user.types.js';
import type {
  HouseholdRecord,
  HouseholdMemberRecord,
} from '../household.types.js';
import {
  GuardedHouseholdService,
  CreateHouseholdInput,
  AddHouseholdMemberInput,
  GetHouseholdMembersResponse,
} from './guarded-household.service.js';

@ApiTags('household')
@Controller('api/household')
export class HouseholdController {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.GUARDED_SERVICE)
    private readonly guardedHouseholdService: GuardedHouseholdService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'List all households for the current user' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Households retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        households: {
          type: 'array',
          items: {
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
        },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  async listHouseholds(
    @CurrentUser() user: UserRecord | null,
  ): Promise<{ households: HouseholdRecord[] }> {
    const result = await this.guardedHouseholdService.listHouseholds(user);
    return result;
  }

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
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  async createHousehold(
    @Body() input: CreateHouseholdInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdRecord> {
    const result = await this.guardedHouseholdService.createHousehold(
      input,
      user,
    );
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
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  @ApiResponse({ status: 404, description: 'Household not found' })
  async getHousehold(
    @Param('id') householdId: string,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdRecord> {
    const result = await this.guardedHouseholdService.getHousehold(
      householdId,
      user,
    );
    return result.household;
  }

  @Get(':id/members')
  @ApiOperation({ summary: 'Get all members of a household' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Household members retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        members: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string' },
              household_id: { type: 'string' },
              user_id: { type: 'string' },
              role: { type: 'string' },
              joined_at: { type: 'string' },
            },
          },
        },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  @ApiResponse({ status: 404, description: 'Household not found' })
  async getHouseholdMembers(
    @Param('id') householdId: string,
    @CurrentUser() user: UserRecord | null,
  ): Promise<GetHouseholdMembersResponse> {
    return this.guardedHouseholdService.getHouseholdMembers(householdId, user);
  }

  @Post(':id/members')
  @ApiOperation({ summary: 'Add a member to household' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 201,
    description: 'Member added successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  async addHouseholdMember(
    @Param('id') householdId: string,
    @Body() input: AddHouseholdMemberInput,
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdMemberRecord> {
    return this.guardedHouseholdService.addHouseholdMember(
      householdId,
      input,
      user,
    );
  }

  @Delete(':id/members/:userId')
  @ApiOperation({ summary: 'Remove a member from household' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 204,
    description: 'Member removed successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  async removeHouseholdMember(
    @Param('id') householdId: string,
    @Param('userId') userId: string,
    @CurrentUser() user: UserRecord | null,
  ): Promise<void> {
    return this.guardedHouseholdService.removeHouseholdMember(
      householdId,
      { userId },
      user,
    );
  }

  @Put(':id/members/:userId/role')
  @ApiOperation({ summary: "Change a member's role in household" })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Member role changed successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 403,
    description: 'Forbidden - Insufficient permissions',
  })
  async changeHouseholdMemberRole(
    @Param('id') householdId: string,
    @Param('userId') userId: string,
    @Body() body: { newRole: string },
    @CurrentUser() user: UserRecord | null,
  ): Promise<HouseholdMemberRecord> {
    return this.guardedHouseholdService.changeHouseholdMemberRole(
      householdId,
      { userId, newRole: body.newRole },
      user,
    );
  }
}
