import {
  SetMetadata,
  createParamDecorator,
  ExecutionContext,
} from '@nestjs/common';
import { GqlExecutionContext } from '@nestjs/graphql';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

// Helper to get request from either HTTP or GraphQL context
const getRequest = (ctx: ExecutionContext) => {
  if (ctx.getType() === 'http') {
    return ctx.switchToHttp().getRequest();
  } else {
    // GraphQL context
    const gqlContext = GqlExecutionContext.create(ctx);
    return gqlContext.getContext().req;
  }
};

// Decorator for auth user (from better-auth)
export const AuthUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext) => {
    const request = getRequest(ctx);
    return request.user;
  },
);

// Decorator for database user (business user)
export const User = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext) => {
    const request = getRequest(ctx);
    return request.dbUser;
  },
);

export const Session = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext) => {
    const request = getRequest(ctx);
    return request.session;
  },
);
