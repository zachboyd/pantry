import { vi } from 'vitest';

// Define the mock type for Better Auth instance following codebase patterns
export type BetterAuthInstanceMockType = {
  api: {
    getSession: ReturnType<typeof vi.fn>;
  };
};

/**
 * Better Auth instance mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class BetterAuthInstanceMock {
  /**
   * Creates a mock Better Auth instance for testing
   * Returns an instance that matches the Better Auth API structure
   */
  static createBetterAuthInstanceMock(): BetterAuthInstanceMockType {
    const mockInstance = {
      api: {
        getSession: vi.fn(),
      },
    } as BetterAuthInstanceMockType;

    return mockInstance;
  }

  /**
   * Creates a Better Auth instance mock with preset successful session behavior
   * Useful for tests that need authenticated sessions
   */
  static createAuthenticatedInstanceMock(): BetterAuthInstanceMockType {
    const mockInstance = this.createBetterAuthInstanceMock();
    
    // Default to successful session
    mockInstance.api.getSession.mockResolvedValue({
      user: {
        id: 'test-user-id',
        email: 'test@example.com',
        name: 'Test User',
        emailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      session: {
        id: 'test-session-id',
        userId: 'test-user-id',
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours from now
        token: 'test-token',
      },
    });

    return mockInstance;
  }

  /**
   * Creates a Better Auth instance mock that simulates authentication failures
   * Useful for testing unauthorized scenarios
   */
  static createUnauthenticatedInstanceMock(): BetterAuthInstanceMockType {
    const mockInstance = this.createBetterAuthInstanceMock();
    
    // Default to failed session (returns null or throws)
    mockInstance.api.getSession.mockResolvedValue(null);

    return mockInstance;
  }
}