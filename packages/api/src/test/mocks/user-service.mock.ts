import { vi } from 'vitest';
import type { UserService, UserRecord } from '../../modules/user/user.types.js';

// Define the mock type for UserService following codebase patterns
export type UserServiceMockType = {
  getUserByAuthId: ReturnType<typeof vi.fn>;
  getUserById: ReturnType<typeof vi.fn>;
  updateUser: ReturnType<typeof vi.fn>;
  createUser: ReturnType<typeof vi.fn>;
  createAIUser: ReturnType<typeof vi.fn>;
  setPrimaryHousehold: ReturnType<typeof vi.fn>;
};

/**
 * UserService mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class UserServiceMock {
  /**
   * Creates a mock UserService for testing
   * By default, all methods return null or reject
   */
  static createUserServiceMock(): UserServiceMockType {
    const mockService = {
      getUserByAuthId: vi.fn().mockResolvedValue(null),
      getUserById: vi.fn().mockResolvedValue(null),
      updateUser: vi.fn().mockResolvedValue(null),
      createUser: vi.fn().mockResolvedValue(null),
      createAIUser: vi.fn().mockResolvedValue(null),
      setPrimaryHousehold: vi.fn().mockResolvedValue(null),
    } as UserServiceMockType;

    return mockService;
  }

  /**
   * Creates a UserService mock that simulates successful operations
   * Returns mock user data for all operations
   */
  static createSuccessfulUserServiceMock(
    mockUser?: Partial<UserRecord>,
  ): UserServiceMockType {
    const defaultUser: UserRecord = {
      id: 'test-user-id',
      first_name: 'Test',
      last_name: 'User',
      email: 'test@example.com',
      auth_user_id: 'test-auth-id',
      avatar_url: null,
      birth_date: null,
      display_name: null,
      is_ai: false,
      managed_by: null,
      permissions: null,
      phone: null,
      preferences: null,
      primary_household_id: null,
      relationship_to_manager: null,
      created_at: new Date(),
      updated_at: new Date(),
    };

    const user = mockUser ? { ...defaultUser, ...mockUser } : defaultUser;
    const mockService = this.createUserServiceMock();

    mockService.getUserByAuthId.mockResolvedValue(user);
    mockService.getUserById.mockResolvedValue(user);
    mockService.updateUser.mockResolvedValue(user);
    mockService.createUser.mockResolvedValue(user);
    mockService.createAIUser.mockResolvedValue(user);
    mockService.setPrimaryHousehold.mockResolvedValue(user);

    return mockService;
  }

  /**
   * Creates a UserService mock that simulates service failures
   * All methods throw errors
   */
  static createFailingUserServiceMock(error?: Error): UserServiceMockType {
    const defaultError = error || new Error('UserService error');
    const mockService = this.createUserServiceMock();

    mockService.getUserByAuthId.mockRejectedValue(defaultError);
    mockService.getUserById.mockRejectedValue(defaultError);
    mockService.updateUser.mockRejectedValue(defaultError);
    mockService.createUser.mockRejectedValue(defaultError);
    mockService.createAIUser.mockRejectedValue(defaultError);
    mockService.setPrimaryHousehold.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a typed UserService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedUserServiceMock(
    mockUser?: Partial<UserRecord>,
  ): UserService {
    const mockService = mockUser
      ? this.createSuccessfulUserServiceMock(mockUser)
      : this.createUserServiceMock();

    return mockService as unknown as UserService;
  }
}
