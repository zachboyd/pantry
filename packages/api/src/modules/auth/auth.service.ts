import { Inject, Injectable } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AuthFactory } from './auth.factory.js';
import type { AuthService } from './auth.types.js';

@Injectable()
export class AuthServiceImpl implements AuthService {
  private authInstance: ReturnType<AuthFactory['createAuthInstance']> | null =
    null;

  constructor(@Inject(TOKENS.AUTH.FACTORY) private authFactory: AuthFactory) {}

  private getAuth() {
    if (!this.authInstance) {
      this.authInstance = this.authFactory.createAuthInstance();
    }
    return this.authInstance;
  }

  async verifySession(headers: Headers | Record<string, string>) {
    try {
      const auth = this.getAuth();

      // Convert headers to Headers object if needed
      const headersObj =
        headers instanceof Headers ? headers : new Headers(headers);

      // Use Better Auth's session verification with cookie headers
      const session = await auth.api.getSession({
        headers: headersObj,
      });
      return session;
    } catch {
      return null;
    }
  }
}
