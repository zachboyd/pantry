import type { AuthUser } from '../../generated/database.js';
import type { Selectable } from 'kysely';

// Type alias for Better Auth user record
export type AuthUserRecord = Selectable<AuthUser>;

/**
 * Repository interface for Better Auth user read operations
 * Provides abstraction over direct database queries for auth_user table
 */
export interface AuthUserRepository {
  /**
   * Get auth user by ID
   */
  getById(id: string): Promise<AuthUserRecord | null>;

  /**
   * Get auth user by email address
   */
  getByEmail(email: string): Promise<AuthUserRecord | null>;
}

/**
 * Service interface for Better Auth user operations
 * Higher-level operations built on top of repository
 */
export interface AuthUserService {
  /**
   * Get auth user by ID
   */
  getById(id: string): Promise<AuthUserRecord | null>;

  /**
   * Get auth user by email address
   */
  getByEmail(email: string): Promise<AuthUserRecord | null>;
}
