import { MongoAbility, ForcedSubject } from '@casl/ability';
import { HouseholdRole } from '../../common/enums.js';

// Define actions that can be performed
export type Action = 'create' | 'read' | 'update' | 'delete' | 'manage'; // manage means all actions

// Define subjects (resources) in the system
export type Subject =
  | 'User'
  | 'Household'
  | 'HouseholdMember'
  | 'Message'
  | 'Pantry'
  | 'all'; // all means all subjects

// CASL Ability type with MongoDB support - using flexible conditions
export type AppAbility = MongoAbility<
  [Action, Subject | ForcedSubject<Subject>],
  Record<string, unknown>
>;

// User context for ability creation
export interface UserContext {
  userId: string;
  households: Array<{
    householdId: string;
    role: HouseholdRole;
  }>;
  // Pre-packed context to avoid database queries during permission checks
  managedUsers: string[]; // User IDs this user can manage directly
  householdMembers: Record<string, string[]>; // householdId -> array of member user IDs
  aiUsers: Record<string, string[]>; // householdId -> array of AI user IDs in that household
}

// Serialized permissions stored in database
export interface SerializedPermissions {
  rules: Array<{
    action: Action | Action[];
    subject: Subject | Subject[];
    conditions?: Record<string, unknown>;
    fields?: string[];
    inverted?: boolean;
  }>;
  version: string; // for future migrations of permission format
}

// Forward declaration for PermissionEvaluator to avoid circular imports
export interface PermissionEvaluator {
  canUpdateUser(targetUserId: string): boolean;
  canReadUser(targetUserId: string): boolean;
  canCreateUser(): boolean;
  canDeleteUser(targetUserId: string): boolean;
  canManageHousehold(householdId: string): boolean;
  canReadHousehold(householdId: string): boolean;
  canCreateHousehold(): boolean;
  canUpdateHousehold(householdId: string): boolean;
  canDeleteHousehold(householdId: string): boolean;
  canManageHouseholdMember(householdId: string): boolean;
  canReadHouseholdMember(householdId: string): boolean;
  canCreateHouseholdMember(householdId: string): boolean;
  canUpdateHouseholdMember(householdId: string, targetRole?: string): boolean;
  canDeleteHouseholdMember(householdId: string): boolean;
  canManageMessage(householdId: string): boolean;
  canCreateMessage(householdId: string): boolean;
  canReadMessage(householdId: string): boolean;
  canUpdateOwnMessage(
    messageId: string,
    householdId: string,
    authorId: string,
  ): boolean;
  canDeleteOwnMessage(
    messageId: string,
    householdId: string,
    authorId: string,
  ): boolean;
  canUpdateAnyMessage(messageId: string, householdId: string): boolean;
  canDeleteAnyMessage(messageId: string, householdId: string): boolean;
  canManagePantry(householdId: string): boolean;
  canReadPantry(householdId: string): boolean;
  canCreatePantryItem(householdId: string): boolean;
  canUpdatePantryItem(householdId: string): boolean;
  canDeletePantryItem(householdId: string): boolean;
  getRawAbility(): AppAbility;
  hasAnyPermission(subject: string): boolean;
}

// Service interface
export interface PermissionService {
  computeUserPermissions(userId: string): Promise<AppAbility>;
  getUserPermissions(userId: string): Promise<AppAbility | null>;

  // Primary permission evaluation method
  getPermissionEvaluator(userId: string): Promise<PermissionEvaluator>;

  // Cache invalidation methods
  invalidateUserPermissions(userId: string): Promise<void>;
  invalidateHouseholdPermissions(householdId: string): Promise<void>;
}
