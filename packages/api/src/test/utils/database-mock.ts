import { vi } from 'vitest';
import type { Kysely, Transaction } from 'kysely';
import type { DB } from '../../generated/database.js';

// Define the mock type with all the necessary properties
export type KyselyMock = Kysely<DB> & {
  mockBuilder: KyselyMockBuilder;
  onConflict: ReturnType<typeof vi.fn>;
  values: ReturnType<typeof vi.fn>;
  selectAll: ReturnType<typeof vi.fn>;
  where: ReturnType<typeof vi.fn>;
  set: ReturnType<typeof vi.fn>;
  returningAll: ReturnType<typeof vi.fn>;
};

/**
 * Kysely mock builder for testing database operations
 */
export class KyselyMockBuilder {
  private executeMock = vi.fn();
  private executeTakeFirstMock = vi.fn();
  private executeTakeFirstOrThrowMock = vi.fn();

  /**
   * Sets up a mock for array-returning queries (execute)
   */
  mockExecute(result: unknown[]) {
    this.executeMock.mockResolvedValue(result);
    return this;
  }

  /**
   * Sets up a mock for single-result queries (executeTakeFirst)
   */
  mockExecuteTakeFirst(result: unknown) {
    this.executeTakeFirstMock.mockResolvedValue(result);
    return this;
  }

  /**
   * Sets up a mock for required single-result queries (executeTakeFirstOrThrow)
   */
  mockExecuteTakeFirstOrThrow(result: unknown) {
    this.executeTakeFirstOrThrowMock.mockResolvedValue(result);
    return this;
  }

  /**
   * Sets up error mocks for all execution methods
   */
  mockError(error: Error) {
    this.executeMock.mockRejectedValue(error);
    this.executeTakeFirstMock.mockRejectedValue(error);
    this.executeTakeFirstOrThrowMock.mockRejectedValue(error);
    return this;
  }

  /**
   * Gets the internal mock functions for direct access if needed
   */
  getMocks() {
    return {
      execute: this.executeMock,
      executeTakeFirst: this.executeTakeFirstMock,
      executeTakeFirstOrThrow: this.executeTakeFirstOrThrowMock,
    };
  }

  /**
   * Builds the Kysely mock instance
   */
  build(): KyselyMock {
    const executeMock = this.executeMock;
    const executeTakeFirstMock = this.executeTakeFirstMock;
    const executeTakeFirstOrThrowMock = this.executeTakeFirstOrThrowMock;

    const conflictBuilderMock = {
      column: vi.fn().mockReturnThis(),
      columns: vi.fn().mockReturnThis(),
      doNothing: vi.fn().mockReturnThis(),
      doUpdateSet: vi.fn().mockReturnThis(),
    };

    const mock = {
      // Query builder methods
      select: vi.fn().mockReturnThis(),
      selectAll: vi.fn().mockReturnThis(),
      selectFrom: vi.fn().mockReturnThis(),
      where: vi.fn().mockReturnThis(),
      whereRef: vi.fn().mockReturnThis(),
      orderBy: vi.fn().mockReturnThis(),
      groupBy: vi.fn().mockReturnThis(),
      having: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      offset: vi.fn().mockReturnThis(),
      innerJoin: vi.fn().mockReturnThis(),
      leftJoin: vi.fn().mockReturnThis(),
      rightJoin: vi.fn().mockReturnThis(),
      fullJoin: vi.fn().mockReturnThis(),

      // Insert operations
      insertInto: vi.fn().mockReturnThis(),
      values: vi.fn().mockReturnThis(),
      returning: vi.fn().mockReturnThis(),
      returningAll: vi.fn().mockReturnThis(),
      onConflict: vi.fn().mockImplementation((callback) => {
        if (typeof callback === 'function') {
          callback(conflictBuilderMock);
        }
        return mock;
      }),
      doNothing: vi.fn().mockReturnThis(),
      doUpdateSet: vi.fn().mockReturnThis(),

      // Update operations
      updateTable: vi.fn().mockReturnThis(),
      set: vi.fn().mockReturnThis(),

      // Delete operations
      deleteFrom: vi.fn().mockReturnThis(),

      // Conflict operations
      column: vi.fn().mockReturnThis(),
      columns: vi.fn().mockReturnThis(),

      // Execute methods
      execute: executeMock,
      executeTakeFirst: executeTakeFirstMock,
      executeTakeFirstOrThrow: executeTakeFirstOrThrowMock,
      stream: vi.fn(),

      // Transaction support
      transaction: vi.fn().mockImplementation((callback) => {
        return Promise.resolve(callback(mock as unknown as Transaction<DB>));
      }),

      // Schema operations
      schema: {
        createTable: vi.fn().mockReturnThis(),
        dropTable: vi.fn().mockReturnThis(),
        alterTable: vi.fn().mockReturnThis(),
        execute: vi.fn(),
      },

      // Utility methods
      destroy: vi.fn(),
      isTransaction: false,

      // Expose the builder for easy access
      mockBuilder: this,
    };

    return mock as unknown as KyselyMock;
  }
}

/**
 * Database mocking utilities for testing
 */
export class DatabaseMock {
  /**
   * Creates a comprehensive Kysely mock with builder pattern
   * @returns Kysely mock with attached builder for easy setup
   */
  static createKyselyMock(): KyselyMock {
    return new KyselyMockBuilder().build();
  }

  /**
   * Creates a pre-configured mock for successful operations
   */
  static createSuccessfulMock(): KyselyMock {
    return new KyselyMockBuilder()
      .mockExecuteTakeFirst(undefined)
      .mockExecuteTakeFirstOrThrow({})
      .mockExecute([])
      .build();
  }

  /**
   * Creates a pre-configured mock for error scenarios
   */
  static createErrorMock(
    error: Error = new Error('Database error'),
  ): KyselyMock {
    return new KyselyMockBuilder().mockError(error).build();
  }

  /**
   * Resets all mocks on a database instance
   */
  static resetMocks() {
    vi.clearAllMocks();
  }
}
