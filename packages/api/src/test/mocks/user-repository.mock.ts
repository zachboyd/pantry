import { vi } from 'vitest';
import type { UserRepository } from '../../modules/user/user.types.js';

// Define the mock type with commonly used properties
export type UserRepositoryMockType = UserRepository & {
  getUserByAuthId: ReturnType<typeof vi.fn>;
  getUserById: ReturnType<typeof vi.fn>;
  updateUser: ReturnType<typeof vi.fn>;
  createUser: ReturnType<typeof vi.fn>;
  findHouseholdAIUser: ReturnType<typeof vi.fn>;
};

/**
 * UserRepository mock factory for consistent testing
 */
export class UserRepositoryMock {
  /**
   * Creates a mock UserRepository instance for testing
   */
  static createUserRepositoryMock(): UserRepositoryMockType {
    const mockRepository = {
      getUserByAuthId: vi.fn(),
      getUserById: vi.fn(),
      updateUser: vi.fn(),
      createUser: vi.fn(),
      findHouseholdAIUser: vi.fn(),
    } as UserRepositoryMockType;

    return mockRepository;
  }
}
