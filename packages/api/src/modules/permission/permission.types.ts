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

// Service interface
export interface PermissionService {
  computeUserPermissions(userId: string): Promise<AppAbility>;
  getUserPermissions(userId: string): Promise<AppAbility | null>;

  // Permission check methods with proper object types
  canCreateHousehold(userId: string): Promise<boolean>;
  canReadHousehold(userId: string, householdId: string): Promise<boolean>;
  canManageHouseholdMember(
    userId: string,
    householdId: string,
  ): Promise<boolean>;
  canViewUser(currentUserId: string, targetUserId: string): Promise<boolean>;

  // Cache invalidation methods
  invalidateUserPermissions(userId: string): Promise<void>;
  invalidateHouseholdPermissions(householdId: string): Promise<void>;
}
