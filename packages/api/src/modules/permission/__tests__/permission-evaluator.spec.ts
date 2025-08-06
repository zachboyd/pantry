import { describe, it, expect } from 'vitest';
import { AbilityFactory } from '../abilities/ability-factory.js';
import { PermissionEvaluator } from '../permission-evaluator.js';
import { HouseholdRole } from '../../../common/enums.js';
import type { UserContext } from '../permission.types.js';

describe('PermissionEvaluator', () => {
  // Helper function to create PermissionEvaluator from UserContext
  function createEvaluator(context: UserContext): PermissionEvaluator {
    const ability = AbilityFactory.createForUser(context);
    return new PermissionEvaluator(ability);
  }
  describe('User Update Permissions', () => {
    it('should allow household managers to update AI users in their household', () => {
      const context: UserContext = {
        userId: 'manager-user',
        households: [{ householdId: 'house-1', role: HouseholdRole.MANAGER }],
        managedUsers: [], // No directly managed users
        householdMembers: {
          'house-1': ['manager-user', 'ai-user', 'member-user'],
        },
        aiUsers: {
          'house-1': ['ai-user'],
        },
      };

      const evaluator = createEvaluator(context);

      // Manager should be able to update AI user in their household
      expect(evaluator.canUpdateUser('ai-user')).toBe(true);

      // Manager should also be able to update themselves
      expect(evaluator.canUpdateUser('manager-user')).toBe(true);
    });

    it('should deny regular members from updating AI users in same household', () => {
      const context: UserContext = {
        userId: 'member-user',
        households: [{ householdId: 'house-1', role: HouseholdRole.MEMBER }],
        managedUsers: [], // No directly managed users
        householdMembers: {
          'house-1': ['manager-user', 'ai-user', 'member-user'],
        },
        aiUsers: {
          'house-1': ['ai-user'],
        },
      };

      const evaluator = createEvaluator(context);

      // Member should NOT be able to update AI user in same household
      expect(evaluator.canUpdateUser('ai-user')).toBe(false);

      // Member should be able to update themselves
      expect(evaluator.canUpdateUser('member-user')).toBe(true);

      // Member should be able to read AI user (but not update)
      expect(evaluator.canReadUser('ai-user')).toBe(true);
    });

    it('should deny managers from updating AI users in different households', () => {
      const context: UserContext = {
        userId: 'manager-user',
        households: [{ householdId: 'house-1', role: HouseholdRole.MANAGER }],
        managedUsers: [], // No directly managed users
        householdMembers: {
          'house-1': ['manager-user', 'member-user'],
          // Note: AI user is NOT in manager's household members
        },
        aiUsers: {
          'house-1': [], // No AI users in manager's household
          'house-2': ['ai-user-other-house'], // AI user in different household
        },
      };

      const evaluator = createEvaluator(context);

      // Manager should NOT be able to update AI user from different household
      expect(evaluator.canUpdateUser('ai-user-other-house')).toBe(false);
    });

    it('should deny non-household members from updating AI users', () => {
      const context: UserContext = {
        userId: 'outsider-user',
        households: [], // No household memberships
        managedUsers: [], // No directly managed users
        householdMembers: {}, // No household access
        aiUsers: {}, // No AI user access
      };

      const evaluator = createEvaluator(context);

      // Outsider should NOT be able to update any AI user
      expect(evaluator.canUpdateUser('ai-user')).toBe(false);

      // Outsider should be able to update themselves
      expect(evaluator.canUpdateUser('outsider-user')).toBe(true);
    });

    it('should deny AI users from updating other users', () => {
      const context: UserContext = {
        userId: 'ai-user',
        households: [{ householdId: 'house-1', role: HouseholdRole.AI }],
        managedUsers: [], // AI users don't manage other users
        householdMembers: {
          'house-1': ['manager-user', 'ai-user'],
        },
        aiUsers: {
          'house-1': ['ai-user'],
        },
      };

      const evaluator = createEvaluator(context);

      // AI user should NOT be able to update other users (including managers)
      expect(evaluator.canUpdateUser('manager-user')).toBe(false);

      // AI user should be able to update themselves
      expect(evaluator.canUpdateUser('ai-user')).toBe(true);
    });

    it('should allow users to update directly managed users', () => {
      const context: UserContext = {
        userId: 'parent-user',
        households: [{ householdId: 'house-1', role: HouseholdRole.MEMBER }],
        managedUsers: ['child-user'], // Directly manages this user
        householdMembers: {
          'house-1': ['parent-user', 'child-user'],
        },
        aiUsers: {
          'house-1': [], // No AI users
        },
      };

      const evaluator = createEvaluator(context);

      // Parent should be able to update managed child
      expect(evaluator.canUpdateUser('child-user')).toBe(true);

      // Parent should be able to update themselves
      expect(evaluator.canUpdateUser('parent-user')).toBe(true);
    });

    it('should evaluate permissions correctly for complex multi-household scenarios', () => {
      const context: UserContext = {
        userId: 'multi-household-user',
        households: [
          { householdId: 'house-1', role: HouseholdRole.MANAGER },
          { householdId: 'house-2', role: HouseholdRole.MEMBER },
        ],
        managedUsers: ['managed-user'], // Directly manages this user
        householdMembers: {
          'house-1': ['multi-household-user', 'ai-user-1'],
          'house-2': ['multi-household-user', 'ai-user-2', 'other-member'],
        },
        aiUsers: {
          'house-1': ['ai-user-1'], // Can manage as MANAGER
          'house-2': ['ai-user-2'], // Cannot manage as MEMBER
        },
      };

      const evaluator = createEvaluator(context);

      // Should be able to update AI user in managed household
      expect(evaluator.canUpdateUser('ai-user-1')).toBe(true);

      // Should NOT be able to update AI user in member household
      expect(evaluator.canUpdateUser('ai-user-2')).toBe(false);

      // Should be able to update directly managed user
      expect(evaluator.canUpdateUser('managed-user')).toBe(true);

      // Should be able to update themselves
      expect(evaluator.canUpdateUser('multi-household-user')).toBe(true);

      // Should NOT be able to update other household members
      expect(evaluator.canUpdateUser('other-member')).toBe(false);
    });
  });

  describe('Basic Permissions', () => {
    it('should allow all users to update their own profile', () => {
      const scenarios = [
        { role: HouseholdRole.MANAGER, userId: 'manager' },
        { role: HouseholdRole.MEMBER, userId: 'member' },
        { role: HouseholdRole.AI, userId: 'ai-user' },
      ];

      scenarios.forEach(({ role, userId }) => {
        const context: UserContext = {
          userId,
          households: [{ householdId: 'house-1', role }],
          managedUsers: [],
          householdMembers: { 'house-1': [userId] },
          aiUsers: role === HouseholdRole.AI ? { 'house-1': [userId] } : {},
        };

        const evaluator = createEvaluator(context);
        expect(evaluator.canUpdateUser(userId)).toBe(true);
      });
    });

    it('should allow all users to create households', () => {
      const context: UserContext = {
        userId: 'any-user',
        households: [],
        managedUsers: [],
        householdMembers: {},
        aiUsers: {},
      };

      const evaluator = createEvaluator(context);
      expect(evaluator.canCreateHousehold()).toBe(true);
    });

    it('should allow users to read their own profile', () => {
      const context: UserContext = {
        userId: 'test-user',
        households: [],
        managedUsers: [],
        householdMembers: {},
        aiUsers: {},
      };

      const evaluator = createEvaluator(context);
      expect(evaluator.canReadUser('test-user')).toBe(true);
    });
  });
});
