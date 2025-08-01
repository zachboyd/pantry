import {
  Injectable,
  Inject,
  BadRequestException,
  UnauthorizedException,
  ForbiddenException,
} from '@nestjs/common';
import { v4 as uuidv4 } from 'uuid';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord } from '../../user/user.types.js';
import type {
  HouseholdRecord,
  HouseholdMemberRecord,
  HouseholdService,
} from '../household.types.js';
import type { PermissionService } from '../../permission/permission.types.js';

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

export interface AddHouseholdMemberInput {
  userId: string;
  role: string;
}

export interface RemoveHouseholdMemberInput {
  userId: string;
}

export interface ChangeHouseholdMemberRoleInput {
  userId: string;
  newRole: string;
}

/**
 * GuardedHouseholdService provides permission-enforced access to household operations
 * This service wraps the core HouseholdService and adds permission guards
 */
@Injectable()
export class GuardedHouseholdService {
  constructor(
    @Inject(TOKENS.HOUSEHOLD.SERVICE)
    private readonly householdService: HouseholdService,
    @Inject(TOKENS.PERMISSION.SERVICE)
    private readonly permissionService: PermissionService,
  ) {}

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
      throw new BadRequestException(
        'Household name must be 100 characters or less',
      );
    }

    // Check permissions - any authenticated user can create a household
    const canCreate = await this.permissionService.canCreateHousehold(user.id);
    if (!canCreate) {
      throw new ForbiddenException('Insufficient permissions to create household');
    }

    // Delegate to service
    const household = await this.householdService.createHousehold(
      {
        id: uuidv4(),
        name: input.name.trim(),
        description: input.description?.trim() || null,
        created_by: user.id,
      },
      user.id,
    );

    return { household };
  }

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

    // Check permissions - user must be a member of the household
    const canRead = await this.permissionService.canReadHousehold(user.id, householdId.trim());
    if (!canRead) {
      throw new ForbiddenException('Insufficient permissions to read this household');
    }

    // Delegate to service
    const household = await this.householdService.getHouseholdById(
      householdId.trim(),
      user.id,
    );

    return { household };
  }

  async addHouseholdMember(
    householdId: string,
    input: AddHouseholdMemberInput,
    user: UserRecord | null,
  ): Promise<HouseholdMemberRecord> {
    // Validation
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!householdId || householdId.trim().length === 0) {
      throw new BadRequestException('Household ID is required');
    }

    if (!input.userId || input.userId.trim().length === 0) {
      throw new BadRequestException('User ID is required');
    }

    if (!input.role || input.role.trim().length === 0) {
      throw new BadRequestException('Role is required');
    }

    // Check permissions - user must be a manager of the household
    const canManage = await this.permissionService.canManageHouseholdMember(user.id, householdId.trim());
    if (!canManage) {
      throw new ForbiddenException('Only household managers can add members');
    }

    // Delegate to service
    return this.householdService.addHouseholdMember(
      householdId.trim(),
      input.userId.trim(),
      input.role.trim(),
      user.id,
    );
  }

  async removeHouseholdMember(
    householdId: string,
    input: RemoveHouseholdMemberInput,
    user: UserRecord | null,
  ): Promise<void> {
    // Validation
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!householdId || householdId.trim().length === 0) {
      throw new BadRequestException('Household ID is required');
    }

    if (!input.userId || input.userId.trim().length === 0) {
      throw new BadRequestException('User ID is required');
    }

    // Check permissions - user must be a manager of the household
    const canManage = await this.permissionService.canManageHouseholdMember(user.id, householdId.trim());
    if (!canManage) {
      throw new ForbiddenException('Only household managers can remove members');
    }

    // Delegate to service
    return this.householdService.removeHouseholdMember(
      householdId.trim(),
      input.userId.trim(),
      user.id,
    );
  }

  async changeHouseholdMemberRole(
    householdId: string,
    input: ChangeHouseholdMemberRoleInput,
    user: UserRecord | null,
  ): Promise<HouseholdMemberRecord> {
    // Validation
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    if (!householdId || householdId.trim().length === 0) {
      throw new BadRequestException('Household ID is required');
    }

    if (!input.userId || input.userId.trim().length === 0) {
      throw new BadRequestException('User ID is required');
    }

    if (!input.newRole || input.newRole.trim().length === 0) {
      throw new BadRequestException('New role is required');
    }

    // Check permissions - user must be a manager of the household
    const canManage = await this.permissionService.canManageHouseholdMember(user.id, householdId.trim());
    if (!canManage) {
      throw new ForbiddenException('Only household managers can change member roles');
    }

    // Delegate to service
    return this.householdService.changeHouseholdMemberRole(
      householdId.trim(),
      input.userId.trim(),
      input.newRole.trim(),
      user.id,
    );
  }
}
