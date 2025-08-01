import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { Kysely } from 'kysely';
import { AbilityBuilder, PureAbility } from '@casl/ability';
import { packRules } from '@casl/ability/extra';
import { PermissionServiceImpl } from '../permission.service.js';
import { TOKENS } from '../../../common/tokens.js';
import { HouseholdRole } from '../../../common/enums.js';
import { DB } from '../../../generated/database.js';
import { AppAbility } from '../permission.types.js';

describe('PermissionService', () => {
  let service: PermissionServiceImpl;
  let mockDb: any;

  beforeEach(async () => {
    // Create mock database
    mockDb = {
      selectFrom: vi.fn().mockReturnValue({
        select: vi.fn().mockReturnValue({
          where: vi.fn().mockReturnValue({
            execute: vi.fn(),
            executeTakeFirst: vi.fn(),
          }),
        }),
      }),
      updateTable: vi.fn().mockReturnValue({
        set: vi.fn().mockReturnValue({
          where: vi.fn().mockReturnValue({
            execute: vi.fn(),
          }),
        }),
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PermissionServiceImpl,
        {
          provide: TOKENS.DATABASE.CONNECTION,
          useValue: mockDb,
        },
      ],
    }).compile();

    service = module.get<PermissionServiceImpl>(PermissionServiceImpl);
  });

  describe('computeUserPermissions', () => {
    it('should compute permissions for user with manager role', async () => {
      const userId = 'user-123';
      const householdId = 'household-456';

      // Mock database response for household roles
      mockDb
        .selectFrom()
        .select()
        .where()
        .execute.mockResolvedValue([
          {
            household_id: householdId,
            role: HouseholdRole.MANAGER,
          },
        ]);

      // Mock update operation
      mockDb.updateTable().set().where().execute.mockResolvedValue(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Test manager permissions
      expect(ability.can('manage', 'Household')).toBe(true);
      expect(ability.can('read', 'User')).toBe(true);
      expect(ability.can('manage', 'Message')).toBe(true);
      expect(ability.can('manage', 'HouseholdMember')).toBe(true);

      // Verify database calls
      expect(mockDb.selectFrom).toHaveBeenCalledWith('household_member');
      expect(mockDb.updateTable).toHaveBeenCalledWith('user');
    });

    it('should compute permissions for user with member role', async () => {
      const userId = 'user-123';
      const householdId = 'household-456';

      mockDb
        .selectFrom()
        .select()
        .where()
        .execute.mockResolvedValue([
          {
            household_id: householdId,
            role: HouseholdRole.MEMBER,
          },
        ]);

      mockDb.updateTable().set().where().execute.mockResolvedValue(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Test member permissions
      expect(ability.can('read', 'Household')).toBe(true);
      expect(ability.can('manage', 'Household')).toBe(false);
      expect(ability.can('create', 'Message')).toBe(true);
      expect(ability.can('read', 'Message')).toBe(true);
      expect(ability.can('read', 'HouseholdMember')).toBe(true);
    });

    it('should compute permissions for user with AI role', async () => {
      const userId = 'user-123';
      const householdId = 'household-456';

      mockDb
        .selectFrom()
        .select()
        .where()
        .execute.mockResolvedValue([
          {
            household_id: householdId,
            role: HouseholdRole.AI,
          },
        ]);

      mockDb.updateTable().set().where().execute.mockResolvedValue(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Test AI permissions
      expect(ability.can('read', 'Household')).toBe(true);
      expect(ability.can('create', 'Message')).toBe(true);
      expect(ability.can('read', 'Message')).toBe(true);
      expect(ability.can('update', 'User')).toBe(false);
      expect(ability.can('create', 'HouseholdMember')).toBe(false);
    });

    it('should handle user with multiple household roles', async () => {
      const userId = 'user-123';

      mockDb
        .selectFrom()
        .select()
        .where()
        .execute.mockResolvedValue([
          {
            household_id: 'household-1',
            role: HouseholdRole.MANAGER,
          },
          {
            household_id: 'household-2',
            role: HouseholdRole.MEMBER,
          },
        ]);

      mockDb.updateTable().set().where().execute.mockResolvedValue(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should have manager permissions (highest level)
      expect(ability.can('manage', 'Household')).toBe(true);
      expect(ability.can('manage', 'Message')).toBe(true);
    });

    it('should handle user with no household roles', async () => {
      const userId = 'user-123';

      mockDb.selectFrom().select().where().execute.mockResolvedValue([]);
      mockDb.updateTable().set().where().execute.mockResolvedValue(undefined);

      const ability = await service.computeUserPermissions(userId);

      // Should only have base permissions (own profile)
      expect(ability.can('read', 'User')).toBe(true);
      expect(ability.can('read', 'Household')).toBe(false);
      expect(ability.can('create', 'Message')).toBe(false);
    });
  });

  describe('getUserPermissions', () => {
    it('should return null when user has no cached permissions', async () => {
      const userId = 'user-123';

      mockDb.selectFrom().select().where().executeTakeFirst.mockResolvedValue({
        permissions: null,
      });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return null when user is not found', async () => {
      const userId = 'user-123';

      mockDb
        .selectFrom()
        .select()
        .where()
        .executeTakeFirst.mockResolvedValue(undefined);

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });

    it('should return ability when user has valid cached permissions', async () => {
      const userId = 'user-123';

      // Create a real ability and pack its rules to get the correct format
      const { can, build } = new AbilityBuilder<AppAbility>(PureAbility);
      can('read', 'User');
      const testAbility = build({
        conditionsMatcher: (conditions) => (object) => {
          if (!conditions) return true;
          for (const [key, value] of Object.entries(conditions)) {
            if (object[key] !== value) return false;
          }
          return true;
        },
      });
      const packedRules = packRules(testAbility.rules);

      const mockPermissions = JSON.stringify(packedRules);

      mockDb.selectFrom().select().where().executeTakeFirst.mockResolvedValue({
        permissions: mockPermissions,
      });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeDefined();
      expect(result?.can('read', 'User')).toBe(true);
    });

    it('should return null when permissions JSON is invalid', async () => {
      const userId = 'user-123';

      mockDb.selectFrom().select().where().executeTakeFirst.mockResolvedValue({
        permissions: 'invalid-json',
      });

      const result = await service.getUserPermissions(userId);

      expect(result).toBeNull();
    });
  });
});
