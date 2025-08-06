import { vi } from 'vitest';
import type { PermissionService } from '../../modules/permission/permission.types.js';
import { PermissionEvaluatorMock } from './permission-evaluator.mock.js';

// Define the mock type for PermissionService following codebase patterns
export type PermissionServiceMockType = {
  computeUserPermissions: ReturnType<typeof vi.fn>;
  getUserPermissions: ReturnType<typeof vi.fn>;
  getPermissionEvaluator: ReturnType<typeof vi.fn>;
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
    const mockEvaluator =
      PermissionEvaluatorMock.createPermissionEvaluatorMock();

    const mockService = {
      computeUserPermissions: vi.fn().mockResolvedValue(null),
      getUserPermissions: vi.fn().mockResolvedValue(null),
      getPermissionEvaluator: vi.fn().mockResolvedValue(mockEvaluator),
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
    const mockEvaluator =
      PermissionEvaluatorMock.createAdminPermissionEvaluatorMock();

    const mockService = {
      computeUserPermissions: vi.fn().mockResolvedValue(null),
      getUserPermissions: vi.fn().mockResolvedValue(null),
      getPermissionEvaluator: vi.fn().mockResolvedValue(mockEvaluator),
      invalidateUserPermissions: vi.fn().mockResolvedValue(undefined),
      invalidateHouseholdPermissions: vi.fn().mockResolvedValue(undefined),
    } as PermissionServiceMockType;

    return mockService;
  }

  /**
   * Creates a PermissionService mock with custom permissions
   * Allows customizing which permissions return true/false
   */
  static createCustomPermissionServiceMock(permissions: {
    canCreate?: boolean;
    canRead?: boolean;
    canManage?: boolean;
    canUpdate?: boolean;
    canDelete?: boolean;
  }): PermissionServiceMockType {
    const mockEvaluator =
      PermissionEvaluatorMock.createPermissionEvaluatorMock(permissions);

    const mockService = {
      computeUserPermissions: vi.fn().mockResolvedValue(null),
      getUserPermissions: vi.fn().mockResolvedValue(null),
      getPermissionEvaluator: vi.fn().mockResolvedValue(mockEvaluator),
      invalidateUserPermissions: vi.fn().mockResolvedValue(undefined),
      invalidateHouseholdPermissions: vi.fn().mockResolvedValue(undefined),
    } as PermissionServiceMockType;

    return mockService;
  }

  /**
   * Creates a PermissionService mock that simulates service failures
   * All methods throw errors
   */
  static createFailingPermissionServiceMock(
    error?: Error,
  ): PermissionServiceMockType {
    const defaultError = error || new Error('Permission service error');

    const mockService = {
      computeUserPermissions: vi.fn().mockRejectedValue(defaultError),
      getUserPermissions: vi.fn().mockRejectedValue(defaultError),
      getPermissionEvaluator: vi.fn().mockRejectedValue(defaultError),
      invalidateUserPermissions: vi.fn().mockRejectedValue(defaultError),
      invalidateHouseholdPermissions: vi.fn().mockRejectedValue(defaultError),
    } as PermissionServiceMockType;

    return mockService;
  }

  /**
   * Creates a typed PermissionService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedPermissionServiceMock(permissions?: {
    canCreate?: boolean;
    canRead?: boolean;
    canManage?: boolean;
    canUpdate?: boolean;
    canDelete?: boolean;
  }): PermissionService {
    const mockService = permissions
      ? this.createCustomPermissionServiceMock(permissions)
      : this.createPermissionServiceMock();

    return mockService as unknown as PermissionService;
  }
}
