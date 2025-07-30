import type { JWK } from 'jose';
import type { UserRecord } from '../user/user.types.js';
import type { CrudEntry } from '@powersync/common';

export type { UserRecord, CrudEntry };

export interface PowerSyncJwtPayload {
  sub: string; // user ID
  aud: string[]; // audience
  iss: string; // issuer
  iat: number; // issued at
  exp: number; // expires at
  user_id: string; // PowerSync-specific user ID claim
  email?: string; // optional email claim
}

export interface PowerSyncAuthRequest {
  token: string; // better-auth session token
}

export interface PowerSyncAuthResponse {
  token: string; // PowerSync JWT
  expires_at: number; // expiration timestamp
}

export interface JwksResponse {
  keys: JWK[];
}

export interface PowerSyncJwtConfig {
  expiresIn: string;
  issuer: string;
  audience: string[];
}

// PowerSync write operation types using CrudEntry
export interface WriteBatchRequest {
  operations: CrudEntry[];
}

export interface WriteOperationError {
  operation_id: number; // index in the operations array
  message: string;
  code?: string;
}

export interface WriteBatchResponse {
  success: boolean;
  errors?: WriteOperationError[];
}

export interface PowerSyncOperationService {
  processOperation(operation: CrudEntry): Promise<void>;
  processOperations(
    operations: CrudEntry[],
    user: UserRecord,
  ): Promise<WriteBatchResponse>;
}

export interface PowerSyncAuthService {
  generateToken(user: UserRecord): Promise<string>;
  verifyToken(token: string): Promise<PowerSyncJwtPayload>;
  getJwks(): Promise<JwksResponse>;
  getExpirationSeconds(): number;
}
