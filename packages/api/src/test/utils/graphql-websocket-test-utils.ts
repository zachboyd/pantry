import { createClient, type Client } from 'graphql-ws';
import WebSocket from 'ws';

/**
 * Utility class for testing GraphQL subscriptions using graphql-ws protocol
 */
export class GraphQLWebSocketTestUtils {
  private static clients: Client[] = [];

  /**
   * Create a GraphQL WebSocket client for testing subscriptions
   */
  static createClient(options: {
    url: string;
    connectionParams?: Record<string, unknown>;
  }): Client {
    const client = createClient({
      url: options.url,
      webSocketImpl: WebSocket,
      connectionParams: options.connectionParams || {},
      retryAttempts: 0, // Don't retry in tests
      shouldRetry: () => false,
    });

    // Keep track of clients for cleanup
    this.clients.push(client);
    return client;
  }

  /**
   * Create an authenticated GraphQL WebSocket client
   */
  static createAuthenticatedClient(options: {
    url: string;
    sessionToken: string;
    additionalParams?: Record<string, unknown>;
  }): Client {
    return this.createClient({
      url: options.url,
      connectionParams: {
        cookie: `jeeves.session_token=${options.sessionToken}`,
        ...options.additionalParams,
      },
    });
  }

  /**
   * Execute a subscription and collect results
   */
  static async executeSubscription<T = any>(options: {
    client: Client;
    query: string;
    variables?: Record<string, unknown>;
    timeout?: number;
    expectedMessages?: number;
  }): Promise<{
    results: T[];
    errors: any[];
    completed: boolean;
  }> {
    const {
      client,
      query,
      variables,
      timeout = 5000,
      expectedMessages = 1,
    } = options;

    return new Promise((resolve, reject) => {
      const results: T[] = [];
      const errors: any[] = [];
      let completed = false;

      // Set timeout
      const timeoutId = setTimeout(() => {
        resolve({
          results,
          errors,
          completed: false,
        });
      }, timeout);

      // Subscribe to the subscription
      const unsubscribe = client.subscribe(
        {
          query,
          variables,
        },
        {
          next: (data) => {
            if (data.errors) {
              errors.push(...data.errors);
            }
            if (data.data) {
              results.push(data.data as T);
            }

            // Auto-resolve if we received expected number of messages
            if (results.length >= expectedMessages) {
              clearTimeout(timeoutId);
              unsubscribe();
              resolve({
                results,
                errors,
                completed: true,
              });
            }
          },
          error: (error) => {
            clearTimeout(timeoutId);
            errors.push(error);
            resolve({
              results,
              errors,
              completed: false,
            });
          },
          complete: () => {
            clearTimeout(timeoutId);
            completed = true;
            resolve({
              results,
              errors,
              completed: true,
            });
          },
        },
      );

      // Also resolve on timeout or if we don't expect any messages
      if (expectedMessages <= 0) {
        setTimeout(() => {
          unsubscribe();
          resolve({
            results,
            errors,
            completed: false,
          });
        }, timeout);
      }
    });
  }

  /**
   * Wait for WebSocket connection to be established
   */
  static async waitForConnection(
    client: Client,
    timeout = 5000,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      let connected = false;

      const timeoutId = setTimeout(() => {
        if (!connected) {
          reject(new Error(`WebSocket connection timeout after ${timeout}ms`));
        }
      }, timeout);

      // Try to subscribe to a simple introspection query to test connection
      const unsubscribe = client.subscribe(
        {
          query: `subscription { __typename }`,
        },
        {
          next: () => {
            // Connection is working
            connected = true;
            clearTimeout(timeoutId);
            unsubscribe();
            resolve();
          },
          error: (error) => {
            // Connection established but subscription failed - that's ok for this test
            if (!connected) {
              connected = true;
              clearTimeout(timeoutId);
              unsubscribe();
              resolve();
            }
          },
          complete: () => {
            if (!connected) {
              connected = true;
              clearTimeout(timeoutId);
              resolve();
            }
          },
        },
      );
    });
  }

  /**
   * Clean up all clients
   */
  static async cleanup(): Promise<void> {
    const promises = this.clients.map((client) => {
      return new Promise<void>((resolve) => {
        try {
          client.dispose();
          resolve();
        } catch (error) {
          // Ignore cleanup errors
          resolve();
        }
      });
    });

    await Promise.all(promises);
    this.clients = [];
  }

  /**
   * Common subscription queries
   */
  static readonly SUBSCRIPTIONS = {
    USER_UPDATED: `
      subscription UserUpdated {
        userUpdated {
          id
          first_name
          last_name
          display_name
          email
          avatar_url
          phone
          birth_date
          primary_household_id
          permissions
          preferences
          is_ai
          created_at
          updated_at
        }
      }
    `,
  };

  /**
   * Assert that a subscription result contains no errors
   */
  static assertNoErrors(result: { errors: any[] }): void {
    if (result.errors && result.errors.length > 0) {
      throw new Error(
        `Subscription errors: ${JSON.stringify(result.errors, null, 2)}`,
      );
    }
  }

  /**
   * Assert that a subscription result has specific errors
   */
  static assertHasErrors(result: { errors: any[] }, expectedCount = 1): void {
    if (!result.errors || result.errors.length !== expectedCount) {
      throw new Error(
        `Expected ${expectedCount} subscription errors, got: ${JSON.stringify(result.errors, null, 2)}`,
      );
    }
  }

  /**
   * Assert that a subscription received expected number of messages
   */
  static assertMessageCount(
    result: { results: any[]; completed: boolean },
    expectedCount: number,
  ): void {
    if (result.results.length !== expectedCount) {
      throw new Error(
        `Expected ${expectedCount} subscription messages, got ${result.results.length}`,
      );
    }
  }

  /**
   * Assert that subscription completed successfully
   */
  static assertCompleted(result: { completed: boolean }): void {
    if (!result.completed) {
      throw new Error('Subscription did not complete successfully');
    }
  }

  /**
   * Assert that subscription did not timeout
   */
  static assertNotTimedOut(result: { completed: boolean }): void {
    if (!result.completed) {
      throw new Error('Subscription timed out');
    }
  }
}
