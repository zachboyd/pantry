import { vi } from 'vitest';
import type { GuardedUserService } from '../../modules/user/api/guarded-user.service.js';

// Define the mock type for GuardedUserService following codebase patterns
export type GuardedUserServiceMockType = {
  getUser: ReturnType<typeof vi.fn>;
  getCurrentUser: ReturnType<typeof vi.fn>;
  updateUser: ReturnType<typeof vi.fn>;
};

/**
 * GuardedUserService mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class GuardedUserServiceMock {
  /**
   * Creates a mock GuardedUserService for testing
   * By default, all methods return null or reject
   */
  static createGuardedUserServiceMock(): GuardedUserServiceMockType {
    const mockService = {
      getUser: vi.fn().mockResolvedValue({ user: null }),
      getCurrentUser: vi.fn().mockResolvedValue({ user: null }),
      updateUser: vi.fn().mockResolvedValue({ user: null }),
    } as GuardedUserServiceMockType;

    return mockService;
  }

  /**
   * Creates a GuardedUserService mock that simulates successful operations
   * Returns mock user data for all operations
   */
  static createSuccessfulGuardedUserServiceMock(mockUser?: any): GuardedUserServiceMockType {
    const defaultUser = {
      id: 'test-user-id',
      first_name: 'Test',
      last_name: 'User',
      email: 'test@example.com',
      created_at: new Date(),
      updated_at: new Date(),
    };

    const user = mockUser || defaultUser;
    const mockService = this.createGuardedUserServiceMock();

    mockService.getUser.mockResolvedValue({ user });
    mockService.getCurrentUser.mockResolvedValue({ user });
    mockService.updateUser.mockResolvedValue({ user });

    return mockService;
  }

  /**
   * Creates a GuardedUserService mock that simulates service failures
   * All methods throw errors
   */
  static createFailingGuardedUserServiceMock(error?: Error): GuardedUserServiceMockType {
    const defaultError = error || new Error('GuardedUserService error');
    const mockService = this.createGuardedUserServiceMock();

    mockService.getUser.mockRejectedValue(defaultError);
    mockService.getCurrentUser.mockRejectedValue(defaultError);
    mockService.updateUser.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a GuardedUserService mock with custom behavior per method
   */
  static createCustomGuardedUserServiceMock(config: {
    getUser?: { user?: any; error?: Error };
    getCurrentUser?: { user?: any; error?: Error };
    updateUser?: { user?: any; error?: Error };
  }): GuardedUserServiceMockType {
    const mockService = this.createGuardedUserServiceMock();

    if (config.getUser) {
      if (config.getUser.error) {
        mockService.getUser.mockRejectedValue(config.getUser.error);
      } else {
        mockService.getUser.mockResolvedValue({ user: config.getUser.user });
      }
    }

    if (config.getCurrentUser) {
      if (config.getCurrentUser.error) {
        mockService.getCurrentUser.mockRejectedValue(config.getCurrentUser.error);
      } else {
        mockService.getCurrentUser.mockResolvedValue({ user: config.getCurrentUser.user });
      }
    }

    if (config.updateUser) {
      if (config.updateUser.error) {
        mockService.updateUser.mockRejectedValue(config.updateUser.error);
      } else {
        mockService.updateUser.mockResolvedValue({ user: config.updateUser.user });
      }
    }

    return mockService;
  }

  /**
   * Creates a typed GuardedUserService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedGuardedUserServiceMock(mockUser?: any): GuardedUserService {
    const mockService = mockUser
      ? this.createSuccessfulGuardedUserServiceMock(mockUser)
      : this.createGuardedUserServiceMock();

    return mockService as unknown as GuardedUserService;
  }
}