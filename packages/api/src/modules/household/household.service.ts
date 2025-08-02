import {
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import type { Insertable } from 'kysely';
import { v4 as uuidv4 } from 'uuid';
import { HouseholdRole } from '../../common/enums.js';
import { TOKENS } from '../../common/tokens.js';
import { EVENTS } from '../../common/events.js';
import { RecomputeUserPermissionsEvent } from '../permission/events/permission-events.js';
import {
  HouseholdCreatedEvent,
  HouseholdMemberAddedEvent,
  HouseholdMemberRemovedEvent,
  HouseholdMemberRoleChangedEvent,
} from './events/household-events.js';
import type { Household } from '../../generated/database.js';
import type {
  HouseholdRepository,
  HouseholdRecord,
  HouseholdMemberRecord,
  HouseholdService,
} from './household.types.js';
import type { UserService } from '../user/user.types.js';

@Injectable()
export class HouseholdServiceImpl implements HouseholdService {
  private readonly logger = new Logger(HouseholdServiceImpl.name);

  constructor(
    @Inject(TOKENS.HOUSEHOLD.REPOSITORY)
    private readonly householdRepository: HouseholdRepository,
    @Inject(TOKENS.USER.SERVICE)
    private readonly userService: UserService,
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

      // 2. Add creator as household manager using service method
      await this.addHouseholdMember(
        createdHousehold.id,
        creatorId,
        HouseholdRole.MANAGER,
        creatorId,
        true, // Skip permission check for initial creation
      );

      // 4. Create AI user for the household using user service
      const aiUser = await this.userService.createAIUser({
        id: uuidv4(),
        email: `ai-assistant+${createdHousehold.id}@system.internal`,
      });

      this.logger.log(
        `Created AI user ${aiUser.id} for household ${createdHousehold.id}`,
      );

      // 5. Add AI user as household member with ai role using service method
      await this.addHouseholdMember(
        createdHousehold.id,
        aiUser.id,
        HouseholdRole.AI,
        creatorId, // Creator adds the AI user
        true, // Skip permission check for initial creation
      );

      // 6. Emit event for downstream processing (notifications, etc.)
      this.eventEmitter.emit(
        EVENTS.HOUSEHOLD.CREATED,
        new HouseholdCreatedEvent(createdHousehold, creatorId, aiUser),
      );

      this.logger.log(
        `Household creation completed successfully: ${createdHousehold.id}`,
      );

      return createdHousehold;
    } catch (error) {
      this.logger.error(`Failed to create household:`, error);
      throw error;
    }
  }

  async getHouseholdById(
    householdId: string,
    userId: string,
  ): Promise<HouseholdRecord> {
    this.logger.log(`Getting household ${householdId} for user ${userId}`);

    try {
      const household = await this.householdRepository.getHouseholdByIdForUser(
        householdId,
        userId,
      );

      if (!household) {
        this.logger.warn(
          `Household ${householdId} not found or user ${userId} does not have access`,
        );
        throw new NotFoundException('Household not found');
      }

      this.logger.log(
        `Successfully retrieved household ${householdId} for user ${userId}`,
      );
      return household;
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      this.logger.error(
        `Failed to get household ${householdId} for user ${userId}:`,
        error,
      );
      throw error;
    }
  }

  async addHouseholdMember(
    householdId: string,
    userId: string,
    role: string,
    requesterId: string,
    skipPermissionCheck: boolean = false,
  ): Promise<HouseholdMemberRecord> {
    this.logger.log(
      `Adding member ${userId} with role ${role} to household ${householdId} by requester ${requesterId}${skipPermissionCheck ? ' (skipping permission check)' : ''}`,
    );

    try {
      // 1. Check if requester has permission (unless skipping for initial creation)
      if (!skipPermissionCheck) {
        const requesterMember =
          await this.householdRepository.getHouseholdMember(
            householdId,
            requesterId,
          );
        if (
          !requesterMember ||
          requesterMember.role !== HouseholdRole.MANAGER
        ) {
          throw new ForbiddenException(
            'Only household managers can add new members',
          );
        }
      }

      // 2. Check if user is already a member
      const existingMember = await this.householdRepository.getHouseholdMember(
        householdId,
        userId,
      );
      if (existingMember) {
        throw new ForbiddenException(
          'User is already a member of this household',
        );
      }

      // 3. Validate role
      if (!Object.values(HouseholdRole).includes(role as HouseholdRole)) {
        throw new ForbiddenException(`Invalid role: ${role}`);
      }

      // 4. Add the member
      const newMember = await this.householdRepository.addHouseholdMember({
        id: uuidv4(),
        household_id: householdId,
        user_id: userId,
        role: role as HouseholdRole,
      });

      this.logger.log(
        `Successfully added member ${userId} to household ${householdId}`,
      );

      // 5. Emit events
      this.eventEmitter.emit(
        EVENTS.HOUSEHOLD.MEMBER_ADDED,
        new HouseholdMemberAddedEvent(householdId, newMember, requesterId),
      );

      // 6. Trigger permission recomputation for the new member
      this.eventEmitter.emit(
        EVENTS.USER.PERMISSIONS.RECOMPUTE,
        new RecomputeUserPermissionsEvent(userId, 'added to household'),
      );

      return newMember;
    } catch (error) {
      if (error instanceof ForbiddenException) {
        throw error;
      }
      this.logger.error(
        `Failed to add member ${userId} to household ${householdId}:`,
        error,
      );
      throw error;
    }
  }

  async removeHouseholdMember(
    householdId: string,
    userId: string,
    requesterId: string,
  ): Promise<void> {
    this.logger.log(
      `Removing member ${userId} from household ${householdId} by requester ${requesterId}`,
    );

    try {
      // 1. Check if requester has permission (must be a manager or removing themselves)
      const requesterMember = await this.householdRepository.getHouseholdMember(
        householdId,
        requesterId,
      );
      if (!requesterMember) {
        throw new ForbiddenException('You are not a member of this household');
      }

      const isSelfRemoval = requesterId === userId;
      const isManager = requesterMember.role === HouseholdRole.MANAGER;

      if (!isSelfRemoval && !isManager) {
        throw new ForbiddenException(
          'Only household managers can remove other members',
        );
      }

      // 2. Get the member to be removed
      const memberToRemove = await this.householdRepository.getHouseholdMember(
        householdId,
        userId,
      );
      if (!memberToRemove) {
        throw new NotFoundException('Member not found in this household');
      }

      // 3. Prevent removing the last manager unless it's a self-removal
      if (memberToRemove.role === HouseholdRole.MANAGER && !isSelfRemoval) {
        const allMembers =
          await this.householdRepository.getHouseholdMembers(householdId);
        const managerCount = allMembers.filter(
          (m) => m.role === HouseholdRole.MANAGER,
        ).length;

        if (managerCount === 1) {
          throw new ForbiddenException(
            'Cannot remove the last manager from the household',
          );
        }
      }

      // 4. Remove the member
      const removedMember =
        await this.householdRepository.removeHouseholdMember(
          householdId,
          userId,
        );
      if (!removedMember) {
        throw new NotFoundException(
          'Failed to remove member - member not found',
        );
      }

      this.logger.log(
        `Successfully removed member ${userId} from household ${householdId}`,
      );

      // 5. Emit events
      this.eventEmitter.emit(
        EVENTS.HOUSEHOLD.MEMBER_REMOVED,
        new HouseholdMemberRemovedEvent(
          householdId,
          removedMember,
          requesterId,
        ),
      );

      // 6. Trigger permission recomputation for the removed member
      this.eventEmitter.emit(
        EVENTS.USER.PERMISSIONS.RECOMPUTE,
        new RecomputeUserPermissionsEvent(userId, 'removed from household'),
      );
    } catch (error) {
      if (
        error instanceof ForbiddenException ||
        error instanceof NotFoundException
      ) {
        throw error;
      }
      this.logger.error(
        `Failed to remove member ${userId} from household ${householdId}:`,
        error,
      );
      throw error;
    }
  }

  async changeHouseholdMemberRole(
    householdId: string,
    userId: string,
    newRole: string,
    requesterId: string,
  ): Promise<HouseholdMemberRecord> {
    this.logger.log(
      `Changing role of member ${userId} to ${newRole} in household ${householdId} by requester ${requesterId}`,
    );

    try {
      // 1. Check if requester has permission (must be a manager)
      const requesterMember = await this.householdRepository.getHouseholdMember(
        householdId,
        requesterId,
      );
      if (!requesterMember || requesterMember.role !== HouseholdRole.MANAGER) {
        throw new ForbiddenException(
          'Only household managers can change member roles',
        );
      }

      // 2. Get the member whose role is being changed
      const memberToUpdate = await this.householdRepository.getHouseholdMember(
        householdId,
        userId,
      );
      if (!memberToUpdate) {
        throw new NotFoundException('Member not found in this household');
      }

      // 3. Validate new role
      if (!Object.values(HouseholdRole).includes(newRole as HouseholdRole)) {
        throw new ForbiddenException(`Invalid role: ${newRole}`);
      }

      // 4. Prevent demoting the last manager
      if (
        memberToUpdate.role === HouseholdRole.MANAGER &&
        newRole !== HouseholdRole.MANAGER
      ) {
        const allMembers =
          await this.householdRepository.getHouseholdMembers(householdId);
        const managerCount = allMembers.filter(
          (m) => m.role === HouseholdRole.MANAGER,
        ).length;

        if (managerCount === 1) {
          throw new ForbiddenException(
            'Cannot demote the last manager from the household',
          );
        }
      }

      const previousRole = memberToUpdate.role;

      // 5. Update the role
      const updatedMember =
        await this.householdRepository.updateHouseholdMemberRole(
          householdId,
          userId,
          newRole,
        );
      if (!updatedMember) {
        throw new NotFoundException(
          'Failed to update member role - member not found',
        );
      }

      this.logger.log(
        `Successfully changed role of member ${userId} from ${previousRole} to ${newRole} in household ${householdId}`,
      );

      // 6. Emit events
      this.eventEmitter.emit(
        EVENTS.HOUSEHOLD.MEMBER_ROLE_CHANGED,
        new HouseholdMemberRoleChangedEvent(
          householdId,
          updatedMember,
          previousRole,
          requesterId,
        ),
      );

      // 7. Trigger permission recomputation for the member whose role changed
      this.eventEmitter.emit(
        EVENTS.USER.PERMISSIONS.RECOMPUTE,
        new RecomputeUserPermissionsEvent(userId, 'role changed in household'),
      );

      return updatedMember;
    } catch (error) {
      if (
        error instanceof ForbiddenException ||
        error instanceof NotFoundException
      ) {
        throw error;
      }
      this.logger.error(
        `Failed to change role of member ${userId} in household ${householdId}:`,
        error,
      );
      throw error;
    }
  }
}
