import { vi } from 'vitest';
import type {
  AuthService,
  BetterAuthSession,
} from '../../modules/auth/auth.types.js';

// Define the mock type for AuthService following codebase patterns
export type AuthServiceMockType = {
  verifySession: ReturnType<typeof vi.fn>;
};

/**
 * Auth Service mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class AuthServiceMock {
  /**
   * Creates a mock AuthService for testing
   * By default, returns null (unauthenticated)
   */
  static createAuthServiceMock(): AuthServiceMockType {
    const mockService = {
      verifySession: vi.fn().mockResolvedValue(null),
    } as AuthServiceMockType;

    return mockService;
  }

  /**
   * Creates an AuthService mock that simulates successful authentication
   * Returns a valid session with user data
   */
  static createAuthenticatedServiceMock(
    customSession?: Partial<BetterAuthSession>,
  ): AuthServiceMockType {
    const defaultSession: BetterAuthSession = {
      user: {
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        emailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        ...customSession?.user,
      },
      session: {
        id: 'test-session-id',
        userId: 'test-user-id',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        token: 'test-token',
        ...customSession?.session,
      },
    };

    const mockService = this.createAuthServiceMock();
    mockService.verifySession.mockResolvedValue(defaultSession);

    return mockService;
  }

  /**
   * Creates an AuthService mock that simulates authentication failures
   * Always returns null or throws errors
   */
  static createUnauthenticatedServiceMock(): AuthServiceMockType {
    const mockService = this.createAuthServiceMock();
    mockService.verifySession.mockResolvedValue(null);

    return mockService;
  }

  /**
   * Creates an AuthService mock that throws authentication errors
   * Useful for testing error handling scenarios
   */
  static createFailingServiceMock(error?: Error): AuthServiceMockType {
    const defaultError = error || new Error('Authentication failed');

    const mockService = this.createAuthServiceMock();
    mockService.verifySession.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a typed AuthService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedAuthServiceMock(
    customSession?: Partial<BetterAuthSession>,
  ): AuthService {
    const mockService = customSession
      ? this.createAuthenticatedServiceMock(customSession)
      : this.createAuthServiceMock();

    return mockService as unknown as AuthService;
  }
}
