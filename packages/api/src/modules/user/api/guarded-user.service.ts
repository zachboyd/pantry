import {
  Injectable,
  Inject,
  UnauthorizedException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { TOKENS } from '../../../common/tokens.js';
import type { UserRecord, UserService } from '../user.types.js';
import type { PermissionService } from '../../permission/permission.types.js';

// Input DTOs for API operations
export interface GetUserInput {
  id: string;
}

export interface UpdateUserInput {
  id: string;
  first_name?: string;
  last_name?: string;
  display_name?: string;
  avatar_url?: string;
  phone?: string;
  birth_date?: Date;
  email?: string;
}

export interface GetUserResponse {
  user: UserRecord;
}

export interface UpdateUserResponse {
  user: UserRecord;
}

/**
 * GuardedUserService provides permission-enforced access to user operations
 * This service wraps the core UserService and adds permission guards
 */
@Injectable()
export class GuardedUserService {
  constructor(
    @Inject(TOKENS.USER.SERVICE)
    private readonly userService: UserService,
    @Inject(TOKENS.PERMISSION.SERVICE)
    private readonly permissionService: PermissionService,
  ) {}

  /**
   * Get user by ID with permission check
   * Users can view their own profile or users they have permission to view
   */
  async getUser(
    userId: string,
    currentUser: UserRecord | null,
  ): Promise<GetUserResponse> {
    if (!currentUser) {
      throw new UnauthorizedException('User must be authenticated');
    }

    // Allow users to view their own profile
    if (currentUser.id === userId) {
      const user = await this.userService.getUserById(userId);
      if (!user) {
        throw new NotFoundException(`User with ID ${userId} not found`);
      }
      return { user };
    }

    // Check if user has permission to view other users
    const canViewUser = await this.permissionService.canViewUser(
      currentUser.id,
      userId,
    );

    if (!canViewUser) {
      throw new ForbiddenException(
        'You do not have permission to view this user',
      );
    }

    const user = await this.userService.getUserById(userId);
    if (!user) {
      throw new NotFoundException(`User with ID ${userId} not found`);
    }

    return { user };
  }

  /**
   * Get current user profile
   */
  async getCurrentUser(
    currentUser: UserRecord | null,
  ): Promise<GetUserResponse> {
    if (!currentUser) {
      // If we reach here with null currentUser, it means the auth session was valid
      // but the business user doesn't exist in the database (orphaned session)
      throw new NotFoundException('Current user not found');
    }

    // Refresh user data from database to ensure it's current
    const user = await this.userService.getUserById(currentUser.id);
    if (!user) {
      throw new NotFoundException('Current user not found');
    }

    return { user };
  }

  /**
   * Update user profile with permission check
   * Users can update their own profile or users they have permission to manage
   */
  async updateUser(
    input: UpdateUserInput,
    currentUser: UserRecord | null,
  ): Promise<UpdateUserResponse> {
    if (!currentUser) {
      throw new UnauthorizedException('User must be authenticated');
    }

    // Check if user exists
    const targetUser = await this.userService.getUserById(input.id);
    if (!targetUser) {
      throw new NotFoundException(`User with ID ${input.id} not found`);
    }

    // Allow users to update their own profile
    if (currentUser.id === input.id) {
      // Extract updatable fields, excluding system fields
      const { id: _id, ...updateData } = input;
      const filteredUpdateData = Object.fromEntries(
        Object.entries(updateData).filter(([, value]) => value !== undefined)
      );

      const updatedUser = await this.userService.updateUser(input.id, filteredUpdateData);
      return { user: updatedUser };
    }

    // Check if user has permission to update other users
    const canUpdateUser = await this.permissionService.canUpdateUser(
      currentUser.id,
      input.id,
    );

    if (!canUpdateUser) {
      throw new ForbiddenException(
        'You do not have permission to update this user',
      );
    }

    // Extract updatable fields, excluding system fields
    const { id: _id, ...updateData } = input;
    const filteredUpdateData = Object.fromEntries(
      Object.entries(updateData).filter(([, value]) => value !== undefined)
    );

    const updatedUser = await this.userService.updateUser(input.id, filteredUpdateData);
    return { user: updatedUser };
  }
}
