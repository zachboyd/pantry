import { vi } from 'vitest';
import type { PubSubService } from '../../modules/pubsub/pubsub.types.js';

export type PubSubServiceMockType = {
  [K in keyof PubSubService]: ReturnType<typeof vi.fn>;
};

export class PubSubServiceMock {
  static createPubSubServiceMock(): PubSubServiceMockType {
    return {
      publishUserUpdated: vi.fn().mockResolvedValue(undefined),
      getUserUpdatedIterator: vi.fn().mockReturnValue({
        [Symbol.asyncIterator]: vi.fn(),
        next: vi.fn().mockResolvedValue({ done: true }),
      }),
    };
  }
}
