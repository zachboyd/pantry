export interface BetterAuthUser {
  id: string;
  email?: string;
  emailVerified: boolean;
  name: string;
  image?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface BetterAuthSession {
  user: BetterAuthUser;
  session: {
    id: string;
    userId: string;
    expiresAt: Date;
    token: string;
    ipAddress?: string;
    userAgent?: string;
  };
}

export interface AuthService {
  verifySession(
    headers: Headers | Record<string, string>,
  ): Promise<BetterAuthSession | null>;
}

export interface AuthSyncService {
  createBusinessUser(authUser: BetterAuthUser): Promise<void>;
}
