import { vi } from 'vitest';
import type { TypingIndicatorRepository } from '../../modules/message/message.types.js';

// Define the mock type with commonly used properties
export type TypingIndicatorRepositoryMockType = TypingIndicatorRepository & {
  save: ReturnType<typeof vi.fn>;
};

/**
 * TypingIndicatorRepository mock factory for consistent testing
 */
export class TypingIndicatorRepositoryMock {
  /**
   * Creates a mock TypingIndicatorRepository instance for testing
   */
  static createTypingIndicatorRepositoryMock(): TypingIndicatorRepositoryMockType {
    const mockRepository = {
      save: vi.fn(),
    } as TypingIndicatorRepositoryMockType;

    return mockRepository;
  }
}
