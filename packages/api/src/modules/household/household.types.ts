import type { Insertable, Selectable } from 'kysely';
import type { Household, HouseholdMember, User } from '../../generated/database.js';

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
  addHouseholdMember(member: Insertable<HouseholdMember>): Promise<HouseholdMemberRecord>;

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
  getHouseholdByIdForUser(householdId: string, userId: string): Promise<HouseholdRecord | null>;

  /**
   * Get households for a user
   * @param userId - User ID
   * @returns Promise with array of household records
   */
  getHouseholdsForUser(userId: string): Promise<HouseholdRecord[]>;

  /**
   * Create an AI user for a household
   * @param aiUser - AI user data to create
   * @returns Promise with the created AI user record
   */
  createAIUser(aiUser: Insertable<User>): Promise<Selectable<User>>;
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
  createHousehold(householdData: Insertable<Household>, creatorId: string): Promise<HouseholdRecord>;

  /**
   * Get household by ID with access control
   * @param householdId - Household ID
   * @param userId - User ID requesting access
   * @returns Promise with household record
   */
  getHouseholdById(householdId: string, userId: string): Promise<HouseholdRecord>;
}