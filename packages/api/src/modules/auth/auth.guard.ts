import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { TOKENS } from '../../common/tokens.js';
import { IS_PUBLIC_KEY } from './auth.decorator.js';
import type { AuthService } from './auth.types.js';
import type { UserService } from '../user/user.types.js';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    @Inject(TOKENS.AUTH.SERVICE) private authService: AuthService,
    @Inject(TOKENS.USER.SERVICE) private userService: UserService,
    private reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) {
      return true;
    }

    const request = context.switchToHttp().getRequest();

    // Check if cookie header exists
    if (!request.headers.cookie) {
      throw new UnauthorizedException('Authentication required');
    }

    try {
      // Pass the request headers to better-auth for session validation
      const session = await this.authService.verifySession({
        cookie: request.headers.cookie,
      });

      if (!session) {
        throw new UnauthorizedException('Invalid session');
      }

      // Add auth user info to request
      request['user'] = session.user;
      request['session'] = session.session;

      // Fetch and add database user to request
      if (session.user?.id) {
        const dbUser = await this.userService.getUserByAuthId(session.user.id);
        request['dbUser'] = dbUser;
      }
    } catch {
      throw new UnauthorizedException('Invalid token');
    }

    return true;
  }
}
