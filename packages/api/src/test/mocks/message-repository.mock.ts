import { vi } from 'vitest';
import type { MessageRepository } from '../../modules/message/message.types.js';

// Define the mock type with commonly used properties
export type MessageRepositoryMockType = MessageRepository & {
  save: ReturnType<typeof vi.fn>;
};

/**
 * MessageRepository mock factory for consistent testing
 */
export class MessageRepositoryMock {
  /**
   * Creates a mock MessageRepository instance for testing
   */
  static createMessageRepositoryMock(): MessageRepositoryMockType {
    const mockRepository = {
      save: vi.fn(),
    } as MessageRepositoryMockType;

    return mockRepository;
  }
}
