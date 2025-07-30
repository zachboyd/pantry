import { vi } from 'vitest';
import type { EventEmitter2 } from '@nestjs/event-emitter';

// Define the mock type with commonly used properties
export type EventEmitter2Mock = EventEmitter2 & {
  emit: ReturnType<typeof vi.fn>;
  emitAsync: ReturnType<typeof vi.fn>;
  on: ReturnType<typeof vi.fn>;
  once: ReturnType<typeof vi.fn>;
  off: ReturnType<typeof vi.fn>;
};

/**
 * EventEmitter2 mock factory for consistent testing
 */
export class EventEmitterMock {
  /**
   * Creates a mock EventEmitter2 instance for testing
   * Provides the most commonly used methods properly mocked
   */
  static createEventEmitterMock(): EventEmitter2Mock {
    const mockEmitter = {
      emit: vi.fn().mockReturnValue(true),
      emitAsync: vi.fn().mockResolvedValue([]),
      on: vi.fn().mockReturnThis(),
      once: vi.fn().mockReturnThis(),
      off: vi.fn().mockReturnThis(),
      removeListener: vi.fn().mockReturnThis(),
      removeAllListeners: vi.fn().mockReturnThis(),
      listeners: vi.fn().mockReturnValue([]),
      listenerCount: vi.fn().mockReturnValue(0),
      setMaxListeners: vi.fn().mockReturnThis(),
      getMaxListeners: vi.fn().mockReturnValue(10),
      addListener: vi.fn().mockReturnThis(),
      prependListener: vi.fn().mockReturnThis(),
      prependOnceListener: vi.fn().mockReturnThis(),
      eventNames: vi.fn().mockReturnValue([]),
      rawListeners: vi.fn().mockReturnValue([]),
      onAny: vi.fn().mockReturnThis(),
      offAny: vi.fn().mockReturnThis(),
      listenTo: vi.fn().mockReturnThis(),
      stopListeningTo: vi.fn().mockReturnThis(),
      many: vi.fn().mockReturnThis(),
      onceAny: vi.fn().mockReturnThis(),
      waitFor: vi.fn().mockResolvedValue(undefined),
    } as unknown as EventEmitter2Mock;

    return mockEmitter;
  }
}
