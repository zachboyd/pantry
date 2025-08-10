import type { User } from '../../generated/database.js';
import type { Insertable, Selectable, Updateable } from 'kysely';

// Runtime type for User queries - what Kysely actually returns
export type UserRecord = Selectable<User>;

// Server-side type for user preferences (flexible JSON)
export type UserPreferences = Record<string, unknown>;

// Server-side type for user permissions (stored as stringified JSON)
export type UserPermissions = string;

/**
 * Interface for User repository operations (pure data access)
 */
export interface UserRepository {
  /**
   * Get user by auth user ID
   * @param authUserId - Auth service user ID
   * @returns Promise with user record or null
   */
  getUserByAuthId(authUserId: string): Promise<UserRecord | null>;

  /**
   * Get user by ID
   * @param id - User ID
   * @returns Promise with user record or null
   */
  getUserById(id: string): Promise<UserRecord | null>;

  /**
   * Update user data
   * @param id - User ID
   * @param userData - User data to update
   * @returns Promise with updated user record
   */
  updateUser(id: string, userData: Updateable<User>): Promise<UserRecord>;

  /**
   * Create a new user
   * @param userData - User data to create
   * @returns Promise with created user record
   */
  createUser(userData: Insertable<User>): Promise<UserRecord>;

  /**
   * Find the AI user for a specific household
   * @param householdId - Household ID
   * @returns Promise with AI user record or null
   */
  findHouseholdAIUser(householdId: string): Promise<UserRecord | null>;
}

/**
 * Interface for User service operations (business logic)
 */
export interface UserService {
  getUserByAuthId(authUserId: string): Promise<UserRecord | null>;
  getUserById(id: string): Promise<UserRecord | null>;
  updateUser(id: string, userData: Updateable<User>): Promise<UserRecord>;
  createUser(userData: Insertable<User>): Promise<UserRecord>;
  createAIUser(userData: Insertable<User>): Promise<UserRecord>;

  /**
   * Set the primary household for a user
   * @param userId - User ID
   * @param householdId - Household ID to set as primary
   * @returns Promise with updated user record
   */
  setPrimaryHousehold(userId: string, householdId: string): Promise<UserRecord>;
}
