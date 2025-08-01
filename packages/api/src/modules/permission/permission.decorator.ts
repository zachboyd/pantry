import { SetMetadata } from '@nestjs/common';
import { Action, Subject } from './permission.types.js';

export const PERMISSION_KEY = 'permission';

export interface RequiredPermission {
  action: Action;
  subject: Subject;
}

export const RequirePermission = (action: Action, subject: Subject) =>
  SetMetadata(PERMISSION_KEY, { action, subject });

// Convenience decorators for common permissions
export const CanRead = (subject: Subject) => RequirePermission('read', subject);
export const CanCreate = (subject: Subject) => RequirePermission('create', subject);
export const CanUpdate = (subject: Subject) => RequirePermission('update', subject);
export const CanDelete = (subject: Subject) => RequirePermission('delete', subject);
export const CanManage = (subject: Subject) => RequirePermission('manage', subject);