export interface BetterAuthUser {
  id: string;
  email: string;
  emailVerified: boolean;
  name: string;
  image?: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthService {
  verifySession(headers: Headers | Record<string, string>): Promise<any>;
}

export interface AuthSyncService {
  createBusinessUser(authUser: BetterAuthUser): Promise<void>;
}
