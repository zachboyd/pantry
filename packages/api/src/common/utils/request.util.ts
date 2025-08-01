import { ExecutionContext } from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';

/**
 * Helper to get request from either HTTP or GraphQL context
 * Works with both REST controllers and GraphQL resolvers
 */
export const getRequest = (ctx: ExecutionContext) => {
  if (ctx.getType() === 'http') {
    return ctx.switchToHttp().getRequest();
  } else {
    // GraphQL context
    const gqlContext = GqlExecutionContext.create(ctx);
    return gqlContext.getContext().req;
  }
};