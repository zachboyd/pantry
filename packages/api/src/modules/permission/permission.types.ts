import { PureAbility } from '@casl/ability';
import { HouseholdRole } from '../../common/enums.js';
import { Json } from '../../generated/database.js';

// Define actions that can be performed
export type Action = 
  | 'create'
  | 'read'
  | 'update'
  | 'delete'
  | 'manage'; // manage means all actions

// Define subjects (resources) in the system
export type Subject = 
  | 'User'
  | 'Household'
  | 'HouseholdMember'
  | 'Message'
  | 'Pantry'
  | 'Attachment'
  | 'all'; // all means all subjects

// CASL Ability type
export type AppAbility = PureAbility<[Action, Subject]>;

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
    conditions?: Record<string, any>;
    fields?: string[];
    inverted?: boolean;
  }>;
  version: string; // for future migrations of permission format
}

// Service interface
export interface PermissionService {
  computeUserPermissions(userId: string): Promise<AppAbility>;
  getUserPermissions(userId: string): Promise<AppAbility | null>;
}