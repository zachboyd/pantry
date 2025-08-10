import { Scalar, CustomScalar } from '@nestjs/graphql';
import { GraphQLDateTime } from 'graphql-scalars';

/**
 * A null-safe wrapper around GraphQLDateTime that handles Redis serialization
 * and null values properly for subscriptions.
 */
@Scalar('DateTime', () => Date)
export class SafeDateTimeScalar implements CustomScalar<string, Date> {
  description = 'A null-safe DateTime scalar';

  serialize(value: unknown): string | null {
    if (value === null || value === undefined) {
      return null;
    }

    try {
      const result = GraphQLDateTime.serialize(value);
      // GraphQLDateTime.serialize returns a Date, convert to ISO string
      return result instanceof Date ? result.toISOString() : result;
    } catch (error) {
      // If GraphQLDateTime fails, try to handle common cases
      if (typeof value === 'string') {
        const date = new Date(value);
        if (!isNaN(date.getTime())) {
          return date.toISOString();
        }
      }
      throw error;
    }
  }

  parseValue(value: unknown): Date | null {
    if (value === null || value === undefined) {
      return null;
    }

    return GraphQLDateTime.parseValue(value);
  }

  parseLiteral(ast: unknown): Date | null {
    return GraphQLDateTime.parseLiteral(ast);
  }
}
