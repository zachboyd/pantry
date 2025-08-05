import { vi } from 'vitest';
import type { PermissionService } from '../../modules/permission/permission.types.js';

// Define the mock type for PermissionService following codebase patterns
export type PermissionServiceMockType = {
  computeUserPermissions: ReturnType<typeof vi.fn>;
  getUserPermissions: ReturnType<typeof vi.fn>;
  canCreateHousehold: ReturnType<typeof vi.fn>;
  canReadHousehold: ReturnType<typeof vi.fn>;
  canManageHouseholdMember: ReturnType<typeof vi.fn>;
  canViewUser: ReturnType<typeof vi.fn>;
  canUpdateUser: ReturnType<typeof vi.fn>;
  canListHouseholds: ReturnType<typeof vi.fn>;
  invalidateUserPermissions: ReturnType<typeof vi.fn>;
  invalidateHouseholdPermissions: ReturnType<typeof vi.fn>;
};

/**
 * Permission Service mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class PermissionServiceMock {
  /**
   * Creates a mock PermissionService for testing
   * By default, all permission checks return false and methods resolve successfully
   */
  static createPermissionServiceMock(): PermissionServiceMockType {
    const mockService = {
      computeUserPermissions: vi.fn().mockResolvedValue(null),
      getUserPermissions: vi.fn().mockResolvedValue(null),
      canCreateHousehold: vi.fn().mockResolvedValue(false),
      canReadHousehold: vi.fn().mockResolvedValue(false),
      canManageHouseholdMember: vi.fn().mockResolvedValue(false),
      canViewUser: vi.fn().mockResolvedValue(false),
      canUpdateUser: vi.fn().mockResolvedValue(false),
      canListHouseholds: vi.fn().mockResolvedValue(false),
      invalidateUserPermissions: vi.fn().mockResolvedValue(undefined),
      invalidateHouseholdPermissions: vi.fn().mockResolvedValue(undefined),
    } as PermissionServiceMockType;

    return mockService;
  }

  /**
   * Creates a PermissionService mock with admin-like permissions
   * All permission checks return true
   */
  static createAdminPermissionServiceMock(): PermissionServiceMockType {
    const mockService = this.createPermissionServiceMock();
    
    // Override permission checks to return true
    mockService.canCreateHousehold.mockResolvedValue(true);
    mockService.canReadHousehold.mockResolvedValue(true);
    mockService.canManageHouseholdMember.mockResolvedValue(true);
    mockService.canViewUser.mockResolvedValue(true);
    mockService.canUpdateUser.mockResolvedValue(true);
    mockService.canListHouseholds.mockResolvedValue(true);

    return mockService;
  }

  /**
   * Creates a PermissionService mock that simulates service failures
   * All methods throw errors
   */
  static createFailingPermissionServiceMock(error?: Error): PermissionServiceMockType {
    const defaultError = error || new Error('Permission service error');
    const mockService = this.createPermissionServiceMock();

    // Override all methods to throw errors
    mockService.computeUserPermissions.mockRejectedValue(defaultError);
    mockService.getUserPermissions.mockRejectedValue(defaultError);
    mockService.canCreateHousehold.mockRejectedValue(defaultError);
    mockService.canReadHousehold.mockRejectedValue(defaultError);
    mockService.canManageHouseholdMember.mockRejectedValue(defaultError);
    mockService.canViewUser.mockRejectedValue(defaultError);
    mockService.canUpdateUser.mockRejectedValue(defaultError);
    mockService.canListHouseholds.mockRejectedValue(defaultError);
    mockService.invalidateUserPermissions.mockRejectedValue(defaultError);
    mockService.invalidateHouseholdPermissions.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a PermissionService mock with specific permission configuration
   * Allows customizing which permissions return true/false
   */
  static createCustomPermissionServiceMock(permissions: {
    canCreate?: boolean;
    canRead?: boolean;
    canManage?: boolean;
    canView?: boolean;
    canUpdate?: boolean;
    canList?: boolean;
  }): PermissionServiceMockType {
    const mockService = this.createPermissionServiceMock();

    if (permissions.canCreate !== undefined) {
      mockService.canCreateHousehold.mockResolvedValue(permissions.canCreate);
    }
    if (permissions.canRead !== undefined) {
      mockService.canReadHousehold.mockResolvedValue(permissions.canRead);
    }
    if (permissions.canManage !== undefined) {
      mockService.canManageHouseholdMember.mockResolvedValue(permissions.canManage);
    }
    if (permissions.canView !== undefined) {
      mockService.canViewUser.mockResolvedValue(permissions.canView);
    }
    if (permissions.canUpdate !== undefined) {
      mockService.canUpdateUser.mockResolvedValue(permissions.canUpdate);
    }
    if (permissions.canList !== undefined) {
      mockService.canListHouseholds.mockResolvedValue(permissions.canList);
    }

    return mockService;
  }

  /**
   * Creates a PermissionService mock that simulates cache invalidation failures
   * Permission checks work normally but cache operations fail
   */
  static createCacheFailurePermissionServiceMock(error?: Error): PermissionServiceMockType {
    const defaultError = error || new Error('Cache operation failed');
    const mockService = this.createPermissionServiceMock();

    // Only cache operations fail
    mockService.invalidateUserPermissions.mockRejectedValue(defaultError);
    mockService.invalidateHouseholdPermissions.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a typed PermissionService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedPermissionServiceMock(
    permissions?: {
      canCreate?: boolean;
      canRead?: boolean;
      canManage?: boolean;
      canView?: boolean;
      canUpdate?: boolean;
      canList?: boolean;
    }
  ): PermissionService {
    const mockService = permissions
      ? this.createCustomPermissionServiceMock(permissions)
      : this.createPermissionServiceMock();

    return mockService as unknown as PermissionService;
  }
}