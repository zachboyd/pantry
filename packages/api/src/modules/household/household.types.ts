import type { Insertable, Selectable } from 'kysely';
import type { Household, HouseholdMember } from '../../generated/database.js';

// Runtime types for Household queries - what Kysely actually returns
export type HouseholdRecord = Selectable<Household>;
export type HouseholdMemberRecord = Selectable<HouseholdMember>;

/**
 * Interface for Household repository operations (pure data access)
 */
export interface HouseholdRepository {
  /**
   * Create a new household
   * @param household - Household data to create
   * @returns Promise with the created household
   */
  createHousehold(household: Insertable<Household>): Promise<HouseholdRecord>;

  /**
   * Add a member to a household
   * @param member - Household member data to add
   * @returns Promise with the created household member record
   */
  addHouseholdMember(
    member: Insertable<HouseholdMember>,
  ): Promise<HouseholdMemberRecord>;

  /**
   * Get household by ID
   * @param householdId - Household ID
   * @returns Promise with household record or null
   */
  getHouseholdById(householdId: string): Promise<HouseholdRecord | null>;

  /**
   * Get household by ID if user has access
   * @param householdId - Household ID
   * @param userId - User ID
   * @returns Promise with household record or null
   */
  getHouseholdByIdForUser(
    householdId: string,
    userId: string,
  ): Promise<HouseholdRecord | null>;

  /**
   * Get households for a user
   * @param userId - User ID
   * @returns Promise with array of household records
   */
  getHouseholdsForUser(userId: string): Promise<HouseholdRecord[]>;

  /**
   * Remove a member from a household
   * @param householdId - Household ID
   * @param userId - User ID to remove
   * @returns Promise with the removed household member record or null if not found
   */
  removeHouseholdMember(
    householdId: string,
    userId: string,
  ): Promise<HouseholdMemberRecord | null>;

  /**
   * Get a household member by household and user ID
   * @param householdId - Household ID
   * @param userId - User ID
   * @returns Promise with household member record or null if not found
   */
  getHouseholdMember(
    householdId: string,
    userId: string,
  ): Promise<HouseholdMemberRecord | null>;

  /**
   * Get all members of a household
   * @param householdId - Household ID
   * @returns Promise with array of household member records
   */
  getHouseholdMembers(householdId: string): Promise<HouseholdMemberRecord[]>;

  /**
   * Update a household member's role
   * @param householdId - Household ID
   * @param userId - User ID
   * @param newRole - New role for the member
   * @returns Promise with updated household member record or null if not found
   */
  updateHouseholdMemberRole(
    householdId: string,
    userId: string,
    newRole: string,
  ): Promise<HouseholdMemberRecord | null>;
}

/**
 * Interface for Household service operations (business logic)
 */
export interface HouseholdService {
  /**
   * Create a household and household membership for creator
   * @param householdData - Household data to create
   * @param creatorId - ID of the user creating the household
   * @returns Promise with the created household
   */
  createHousehold(
    householdData: Insertable<Household>,
    creatorId: string,
  ): Promise<HouseholdRecord>;

  /**
   * Get household by ID with access control
   * @param householdId - Household ID
   * @param userId - User ID requesting access
   * @returns Promise with household record
   */
  getHouseholdById(
    householdId: string,
    userId: string,
  ): Promise<HouseholdRecord>;

  /**
   * Add a member to a household
   * @param householdId - Household ID
   * @param userId - User ID to add
   * @param role - Role for the new member
   * @param requesterId - ID of user making the request (for permission checks)
   * @param skipPermissionCheck - Skip permission validation (for initial household creation)
   * @returns Promise with the created household member record
   */
  addHouseholdMember(
    householdId: string,
    userId: string,
    role: string,
    requesterId: string,
    skipPermissionCheck?: boolean,
  ): Promise<HouseholdMemberRecord>;

  /**
   * Remove a member from a household
   * @param householdId - Household ID
   * @param userId - User ID to remove
   * @param requesterId - ID of user making the request (for permission checks)
   * @returns Promise with void (throws if not authorized or member not found)
   */
  removeHouseholdMember(
    householdId: string,
    userId: string,
    requesterId: string,
  ): Promise<void>;

  /**
   * Change a member's role in a household
   * @param householdId - Household ID
   * @param userId - User ID whose role to change
   * @param newRole - New role for the member
   * @param requesterId - ID of user making the request (for permission checks)
   * @returns Promise with updated household member record
   */
  changeHouseholdMemberRole(
    householdId: string,
    userId: string,
    newRole: string,
    requesterId: string,
  ): Promise<HouseholdMemberRecord>;

  /**
   * Get all households for a user
   * @param userId - User ID
   * @returns Promise with array of household records
   */
  getHouseholdsForUser(userId: string): Promise<HouseholdRecord[]>;
}
