import type { UserRecord } from '../user/user.types.js';

export interface RedisConfig {
  url: string;
}

export interface UserUpdatedEvent {
  userUpdated: UserRecord;
}

export interface PubSubService {
  /**
   * Publishes a user update event when user data (especially permissions) changes
   * @param userId - The ID of the user that was updated
   * @param userData - The updated user data
   */
  publishUserUpdated(userId: string, userData: UserRecord): Promise<void>;

  /**
   * Gets an async iterator for user update subscriptions
   * @param userId - The ID of the user to subscribe to
   * @returns AsyncIterator for the user update events
   */
  getUserUpdatedIterator(userId: string): AsyncIterator<UserUpdatedEvent>;
}
