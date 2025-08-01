import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PureAbility } from '@casl/ability';
import { unpackRules } from '@casl/ability/extra';
import { TOKENS } from '../../common/tokens.js';
import { getRequest } from '../../common/utils/request.util.js';
import { PermissionService, AppAbility } from './permission.types.js';
import { PERMISSION_KEY, RequiredPermission } from './permission.decorator.js';

@Injectable()
export class PermissionGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    @Inject(TOKENS.PERMISSION.SERVICE)
    private readonly permissionService: PermissionService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermission =
      this.reflector.getAllAndOverride<RequiredPermission>(PERMISSION_KEY, [
        context.getHandler(),
        context.getClass(),
      ]);

    if (!requiredPermission) {
      return true; // No permission required
    }

    const request = getRequest(context);
    const user = request.user;
    const dbUser = request.dbUser;

    if (!user?.id || !dbUser?.id) {
      throw new ForbiddenException('User not authenticated');
    }

    try {
      let ability: AppAbility;

      // Try to use cached permissions from dbUser first
      if (dbUser.permissions) {
        try {
          const packedRules = JSON.parse(dbUser.permissions as string);
          const rules = unpackRules(packedRules);
          ability = new PureAbility(rules, {
            conditionsMatcher: (conditions) => (object) => {
              if (!conditions) return true;

              for (const [key, value] of Object.entries(conditions)) {
                if (key.includes('.')) {
                  // Handle nested property access like 'household_members.household_id'
                  const keys = key.split('.');
                  let current = object;
                  for (const k of keys) {
                    if (current?.[k] === undefined) return false;
                    current = current[k];
                  }
                  if (current !== value) return false;
                } else if (typeof value === 'object' && value !== null) {
                  // Handle special operators like { $exists: true }
                  if ('$exists' in value) {
                    const exists =
                      object[key] !== undefined && object[key] !== null;
                    if (exists !== value.$exists) return false;
                  }
                } else {
                  // Simple property match
                  if (object[key] !== value) return false;
                }
              }
              return true;
            },
          });
        } catch {
          // If parsing fails, compute fresh permissions
          ability = await this.permissionService.computeUserPermissions(
            dbUser.id,
          );
        }
      } else {
        // No cached permissions, compute fresh ones
        ability = await this.permissionService.computeUserPermissions(
          dbUser.id,
        );
      }

      const hasPermission = ability.can(
        requiredPermission.action,
        requiredPermission.subject,
      );

      if (!hasPermission) {
        throw new ForbiddenException(
          `Insufficient permissions: cannot ${requiredPermission.action} ${requiredPermission.subject}`,
        );
      }

      return true;
    } catch (error) {
      if (error instanceof ForbiddenException) {
        throw error;
      }
      throw new ForbiddenException('Permission check failed');
    }
  }
}
