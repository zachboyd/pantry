import { vi } from 'vitest';

/**
 * Factory for creating consistent mocks across tests
 */
export class MockFactory {
  /**
   * Creates a mock service with common methods
   */
  static createServiceMock(
    methods: string[] = [],
  ): Record<string, ReturnType<typeof vi.fn>> {
    const mock: Record<string, ReturnType<typeof vi.fn>> = {};

    methods.forEach((method) => {
      mock[method] = vi.fn();
    });

    return mock;
  }

  /**
   * Creates a mock logger
   */
  static createLoggerMock() {
    return {
      log: vi.fn(),
      error: vi.fn(),
      warn: vi.fn(),
      debug: vi.fn(),
      verbose: vi.fn(),
    };
  }

  /**
   * Creates a mock repository pattern
   */
  static createRepositoryMock(
    methods: string[] = ['find', 'findOne', 'save', 'delete', 'update'],
  ) {
    return this.createServiceMock(methods);
  }
}
