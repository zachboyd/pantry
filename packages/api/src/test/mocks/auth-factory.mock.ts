import { vi } from 'vitest';
import type { AuthFactory } from '../../modules/auth/auth.factory.js';
import { BetterAuthInstanceMock, type BetterAuthInstanceMockType } from './better-auth-instance.mock.js';

// Define the mock type for AuthFactory following codebase patterns
export type AuthFactoryMockType = {
  createAuthInstance: ReturnType<typeof vi.fn>;
};

/**
 * Auth Factory mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class AuthFactoryMock {
  /**
   * Creates a mock AuthFactory for testing
   * Returns a factory that creates Better Auth instances
   */
  static createAuthFactoryMock(
    customInstance?: BetterAuthInstanceMockType
  ): AuthFactoryMockType {
    const defaultInstance = customInstance || BetterAuthInstanceMock.createBetterAuthInstanceMock();
    
    const mockFactory = {
      createAuthInstance: vi.fn().mockReturnValue(defaultInstance),
    } as AuthFactoryMockType;

    return mockFactory;
  }

  /**
   * Creates an AuthFactory mock that returns authenticated instances
   * Useful for tests that need successful authentication
   */
  static createAuthenticatedFactoryMock(): AuthFactoryMockType {
    const authenticatedInstance = BetterAuthInstanceMock.createAuthenticatedInstanceMock();
    return this.createAuthFactoryMock(authenticatedInstance);
  }

  /**
   * Creates an AuthFactory mock that returns unauthenticated instances
   * Useful for tests that need authentication failures
   */
  static createUnauthenticatedFactoryMock(): AuthFactoryMockType {
    const unauthenticatedInstance = BetterAuthInstanceMock.createUnauthenticatedInstanceMock();
    return this.createAuthFactoryMock(unauthenticatedInstance);
  }

  /**
   * Creates a typed AuthFactory mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedAuthFactoryMock(
    customInstance?: BetterAuthInstanceMockType
  ): AuthFactory {
    const mockFactory = this.createAuthFactoryMock(customInstance);
    return mockFactory as unknown as AuthFactory;
  }
}