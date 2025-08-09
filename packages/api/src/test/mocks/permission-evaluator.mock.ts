import { vi } from 'vitest';
import type { PermissionEvaluator } from '../../modules/permission/permission.types.js';

// Mock PermissionEvaluator type
export type PermissionEvaluatorMockType = {
  canUpdateUser: ReturnType<typeof vi.fn>;
  canReadUser: ReturnType<typeof vi.fn>;
  canCreateUser: ReturnType<typeof vi.fn>;
  canDeleteUser: ReturnType<typeof vi.fn>;
  canManageHousehold: ReturnType<typeof vi.fn>;
  canReadHousehold: ReturnType<typeof vi.fn>;
  canCreateHousehold: ReturnType<typeof vi.fn>;
  canUpdateHousehold: ReturnType<typeof vi.fn>;
  canDeleteHousehold: ReturnType<typeof vi.fn>;
  canManageHouseholdMember: ReturnType<typeof vi.fn>;
  canReadHouseholdMember: ReturnType<typeof vi.fn>;
  canCreateHouseholdMember: ReturnType<typeof vi.fn>;
  canUpdateHouseholdMember: ReturnType<typeof vi.fn>;
  canDeleteHouseholdMember: ReturnType<typeof vi.fn>;
  canManageMessage: ReturnType<typeof vi.fn>;
  canCreateMessage: ReturnType<typeof vi.fn>;
  canReadMessage: ReturnType<typeof vi.fn>;
  canUpdateOwnMessage: ReturnType<typeof vi.fn>;
  canDeleteOwnMessage: ReturnType<typeof vi.fn>;
  canUpdateAnyMessage: ReturnType<typeof vi.fn>;
  canDeleteAnyMessage: ReturnType<typeof vi.fn>;
  getRawAbility: ReturnType<typeof vi.fn>;
  hasAnyPermission: ReturnType<typeof vi.fn>;
};

/**
 * PermissionEvaluator mock factory for consistent testing
 */
export class PermissionEvaluatorMock {
  /**
   * Creates a mock PermissionEvaluator
   */
  static createPermissionEvaluatorMock(
    permissions: {
      canUpdate?: boolean;
      canRead?: boolean;
      canCreate?: boolean;
      canDelete?: boolean;
      canManage?: boolean;
    } = {},
  ): PermissionEvaluatorMockType {
    const defaultPermissions = {
      canUpdate: false,
      canRead: false,
      canCreate: false,
      canDelete: false,
      canManage: false,
      ...permissions,
    };

    return {
      canUpdateUser: vi.fn().mockReturnValue(defaultPermissions.canUpdate),
      canReadUser: vi.fn().mockReturnValue(defaultPermissions.canRead),
      canCreateUser: vi.fn().mockReturnValue(defaultPermissions.canCreate),
      canDeleteUser: vi.fn().mockReturnValue(defaultPermissions.canDelete),
      canManageHousehold: vi.fn().mockReturnValue(defaultPermissions.canManage),
      canReadHousehold: vi.fn().mockReturnValue(defaultPermissions.canRead),
      canCreateHousehold: vi.fn().mockReturnValue(defaultPermissions.canCreate),
      canUpdateHousehold: vi.fn().mockReturnValue(defaultPermissions.canUpdate),
      canDeleteHousehold: vi.fn().mockReturnValue(defaultPermissions.canDelete),
      canManageHouseholdMember: vi
        .fn()
        .mockReturnValue(defaultPermissions.canManage),
      canReadHouseholdMember: vi
        .fn()
        .mockReturnValue(defaultPermissions.canRead),
      canCreateHouseholdMember: vi
        .fn()
        .mockReturnValue(defaultPermissions.canCreate),
      canUpdateHouseholdMember: vi
        .fn()
        .mockReturnValue(defaultPermissions.canUpdate),
      canDeleteHouseholdMember: vi
        .fn()
        .mockReturnValue(defaultPermissions.canDelete),
      canManageMessage: vi.fn().mockReturnValue(defaultPermissions.canManage),
      canCreateMessage: vi.fn().mockReturnValue(defaultPermissions.canCreate),
      canReadMessage: vi.fn().mockReturnValue(defaultPermissions.canRead),
      canUpdateOwnMessage: vi
        .fn()
        .mockReturnValue(defaultPermissions.canUpdate),
      canDeleteOwnMessage: vi
        .fn()
        .mockReturnValue(defaultPermissions.canDelete),
      canUpdateAnyMessage: vi
        .fn()
        .mockReturnValue(defaultPermissions.canUpdate),
      canDeleteAnyMessage: vi
        .fn()
        .mockReturnValue(defaultPermissions.canDelete),
      getRawAbility: vi.fn().mockReturnValue(null),
      hasAnyPermission: vi.fn().mockReturnValue(false),
    } as PermissionEvaluatorMockType;
  }

  /**
   * Creates a PermissionEvaluator mock with admin-like permissions
   */
  static createAdminPermissionEvaluatorMock(): PermissionEvaluatorMockType {
    return this.createPermissionEvaluatorMock({
      canUpdate: true,
      canRead: true,
      canCreate: true,
      canDelete: true,
      canManage: true,
    });
  }

  /**
   * Creates a typed PermissionEvaluator mock for dependency injection
   */
  static createTypedPermissionEvaluatorMock(permissions?: {
    canUpdate?: boolean;
    canRead?: boolean;
    canCreate?: boolean;
    canDelete?: boolean;
    canManage?: boolean;
  }): PermissionEvaluator {
    const mockEvaluator = permissions
      ? this.createPermissionEvaluatorMock(permissions)
      : this.createPermissionEvaluatorMock();

    return mockEvaluator as unknown as PermissionEvaluator;
  }
}
