import {
  SetMetadata,
  createParamDecorator,
  ExecutionContext,
} from '@nestjs/common';
import { getRequest } from '../../common/utils/request.util.js';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);

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
