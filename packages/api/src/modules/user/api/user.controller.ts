import {
  Controller,
  Get,
  Inject,
  Param,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { TOKENS } from '../../../common/tokens.js';
import { User } from '../../auth/auth.decorator.js';
import type { UserRecord } from '../user.types.js';
import { GuardedUserService } from './guarded-user.service.js';

@ApiTags('user')
@Controller('api/user')
export class UserController {
  constructor(
    @Inject(TOKENS.USER.GUARDED_SERVICE)
    private readonly guardedUserService: GuardedUserService,
  ) {}

  @Get('current')
  @ApiOperation({ summary: 'Get current user profile' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Current user retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        auth_user_id: { type: 'string', nullable: true },
        email: { type: 'string', nullable: true },
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        display_name: { type: 'string', nullable: true },
        avatar_url: { type: 'string', nullable: true },
        phone: { type: 'string', nullable: true },
        birth_date: { type: 'string', nullable: true },
        managed_by: { type: 'string', nullable: true },
        relationship_to_manager: { type: 'string', nullable: true },
        created_at: { type: 'string' },
        updated_at: { type: 'string' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  async getCurrentUser(@User() user: UserRecord | null): Promise<UserRecord> {
    const result = await this.guardedUserService.getCurrentUser(user);
    return result.user;
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'User retrieved successfully',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        auth_user_id: { type: 'string', nullable: true },
        email: { type: 'string', nullable: true },
        first_name: { type: 'string' },
        last_name: { type: 'string' },
        display_name: { type: 'string', nullable: true },
        avatar_url: { type: 'string', nullable: true },
        phone: { type: 'string', nullable: true },
        birth_date: { type: 'string', nullable: true },
        managed_by: { type: 'string', nullable: true },
        relationship_to_manager: { type: 'string', nullable: true },
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
  @ApiResponse({ status: 404, description: 'User not found' })
  async getUser(
    @Param('id') userId: string,
    @User() user: UserRecord | null,
  ): Promise<UserRecord> {
    const result = await this.guardedUserService.getUser(userId, user);
    return result.user;
  }
}