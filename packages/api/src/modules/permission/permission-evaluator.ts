import { subject } from '@casl/ability';
import type { AppAbility } from './permission.types.js';

/**
 * PermissionEvaluator provides a clean, semantic API for evaluating permissions.
 * It wraps the raw CASL AppAbility with meaningful method names that make
 * permission requirements explicit and easier to understand.
 */
export class PermissionEvaluator {
  constructor(private readonly ability: AppAbility) {}

  // ============================================================================
  // USER PERMISSIONS
  // ============================================================================

  /**
   * Check if the user can update another user's profile
   */
  canUpdateUser(targetUserId: string): boolean {
    return this.ability.can('update', subject('User', { id: targetUserId }));
  }

  /**
   * Check if the user can read another user's profile
   */
  canReadUser(targetUserId: string): boolean {
    return this.ability.can('read', subject('User', { id: targetUserId }));
  }

  /**
   * Check if the user can create new users (typically system-level permission)
   */
  canCreateUser(): boolean {
    return this.ability.can('create', 'User');
  }

  /**
   * Check if the user can delete another user
   */
  canDeleteUser(targetUserId: string): boolean {
    return this.ability.can('delete', subject('User', { id: targetUserId }));
  }

  // ============================================================================
  // HOUSEHOLD PERMISSIONS
  // ============================================================================

  /**
   * Check if the user can manage a specific household (full access)
   */
  canManageHousehold(householdId: string): boolean {
    return this.ability.can(
      'manage',
      subject('Household', { id: householdId }),
    );
  }

  /**
   * Check if the user can read/view a specific household
   */
  canReadHousehold(householdId: string): boolean {
    return this.ability.can('read', subject('Household', { id: householdId }));
  }

  /**
   * Check if the user can create new households
   */
  canCreateHousehold(): boolean {
    return this.ability.can('create', 'Household');
  }

  /**
   * Check if the user can update a specific household
   */
  canUpdateHousehold(householdId: string): boolean {
    return this.ability.can(
      'update',
      subject('Household', { id: householdId }),
    );
  }

  /**
   * Check if the user can delete a specific household
   */
  canDeleteHousehold(householdId: string): boolean {
    return this.ability.can(
      'delete',
      subject('Household', { id: householdId }),
    );
  }

  // ============================================================================
  // HOUSEHOLD MEMBER PERMISSIONS
  // ============================================================================

  /**
   * Check if the user can manage household members in a specific household
   */
  canManageHouseholdMember(householdId: string): boolean {
    return this.ability.can(
      'manage',
      subject('HouseholdMember', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can read household member information for a specific household
   */
  canReadHouseholdMember(householdId: string): boolean {
    return this.ability.can(
      'read',
      subject('HouseholdMember', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can add new members to a specific household
   */
  canCreateHouseholdMember(householdId: string): boolean {
    return this.ability.can(
      'create',
      subject('HouseholdMember', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can update household member roles/info in a specific household
   */
  canUpdateHouseholdMember(householdId: string, targetRole?: string): boolean {
    const conditions: Record<string, unknown> = { household_id: householdId };
    if (targetRole) {
      conditions.role = targetRole;
    }
    return this.ability.can('update', subject('HouseholdMember', conditions));
  }

  /**
   * Check if the user can remove members from a specific household
   */
  canDeleteHouseholdMember(householdId: string): boolean {
    return this.ability.can(
      'delete',
      subject('HouseholdMember', { household_id: householdId }),
    );
  }

  // ============================================================================
  // MESSAGE PERMISSIONS
  // ============================================================================

  /**
   * Check if the user can manage all messages in a specific household
   */
  canManageMessage(householdId: string): boolean {
    return this.ability.can(
      'manage',
      subject('Message', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can create messages in a specific household
   */
  canCreateMessage(householdId: string): boolean {
    return this.ability.can(
      'create',
      subject('Message', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can read messages in a specific household
   */
  canReadMessage(householdId: string): boolean {
    return this.ability.can(
      'read',
      subject('Message', { household_id: householdId }),
    );
  }

  /**
   * Check if the user can update their own message
   */
  canUpdateOwnMessage(
    messageId: string,
    householdId: string,
    authorId: string,
  ): boolean {
    return this.ability.can(
      'update',
      subject('Message', {
        id: messageId,
        household_id: householdId,
        user_id: authorId,
      }),
    );
  }

  /**
   * Check if the user can delete their own message
   */
  canDeleteOwnMessage(
    messageId: string,
    householdId: string,
    authorId: string,
  ): boolean {
    return this.ability.can(
      'delete',
      subject('Message', {
        id: messageId,
        household_id: householdId,
        user_id: authorId,
      }),
    );
  }

  /**
   * Check if the user can update any message in a household (manager permission)
   */
  canUpdateAnyMessage(messageId: string, householdId: string): boolean {
    return this.ability.can(
      'update',
      subject('Message', {
        id: messageId,
        household_id: householdId,
      }),
    );
  }

  /**
   * Check if the user can delete any message in a household (manager permission)
   */
  canDeleteAnyMessage(messageId: string, householdId: string): boolean {
    return this.ability.can(
      'delete',
      subject('Message', {
        id: messageId,
        household_id: householdId,
      }),
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get the raw ability instance for advanced use cases
   * Use sparingly - prefer the semantic methods above
   */
  getRawAbility(): AppAbility {
    return this.ability;
  }

  /**
   * Check if the user has any permission on a subject
   */
  hasAnyPermission(subjectName: string): boolean {
    // Type assertion is safe here since we're checking against known subject types
    const subjectType = subjectName as
      | 'User'
      | 'Household'
      | 'HouseholdMember'
      | 'Message';
    return (
      this.ability.can('read', subjectType) ||
      this.ability.can('create', subjectType) ||
      this.ability.can('update', subjectType) ||
      this.ability.can('delete', subjectType) ||
      this.ability.can('manage', subjectType)
    );
  }
}
