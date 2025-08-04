import { Injectable, Inject, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { TOKENS } from '../../common/tokens.js';
import { EVENTS } from '../../common/events.js';
import { PermissionService } from './permission.types.js';
import { RecomputeUserPermissionsEvent } from './events/permission-events.js';

@Injectable()
export class PermissionEventHandler {
  private readonly logger = new Logger(PermissionEventHandler.name);

  constructor(
    @Inject(TOKENS.PERMISSION.SERVICE)
    private readonly permissionService: PermissionService,
  ) {}

  @OnEvent(EVENTS.USER.PERMISSIONS.RECOMPUTE)
  async handleRecomputeUserPermissions(event: RecomputeUserPermissionsEvent) {
    try {
      // First invalidate cached permissions to ensure fresh computation
      await this.permissionService.invalidateUserPermissions(event.userId);
      
      // Then recompute fresh permissions
      await this.permissionService.computeUserPermissions(event.userId);
      
      this.logger.log(
        `Recomputed permissions for user ${event.userId}${event.reason ? ` (${event.reason})` : ''}`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to recompute permissions for user ${event.userId}:`,
        error,
      );
    }
  }
}
