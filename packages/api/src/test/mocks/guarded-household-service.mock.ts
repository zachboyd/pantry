import { vi } from 'vitest';
import type { GuardedHouseholdService } from '../../modules/household/api/guarded-household.service.js';
import type {
  HouseholdRecord,
  HouseholdMemberRecord,
} from '../../modules/household/household.types.js';

// Define the mock type for GuardedHouseholdService following codebase patterns
export type GuardedHouseholdServiceMockType = {
  createHousehold: ReturnType<typeof vi.fn>;
  getHousehold: ReturnType<typeof vi.fn>;
  addHouseholdMember: ReturnType<typeof vi.fn>;
  removeHouseholdMember: ReturnType<typeof vi.fn>;
  changeHouseholdMemberRole: ReturnType<typeof vi.fn>;
  listHouseholds: ReturnType<typeof vi.fn>;
  getHouseholdMembers: ReturnType<typeof vi.fn>;
  updateHousehold: ReturnType<typeof vi.fn>;
  getHouseholdMemberCount: ReturnType<typeof vi.fn>;
};

/**
 * GuardedHouseholdService mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class GuardedHouseholdServiceMock {
  /**
   * Creates a mock GuardedHouseholdService for testing
   * By default, all methods return null or reject
   */
  static createGuardedHouseholdServiceMock(): GuardedHouseholdServiceMockType {
    const mockService = {
      createHousehold: vi.fn().mockResolvedValue({ household: null }),
      getHousehold: vi.fn().mockResolvedValue({ household: null }),
      addHouseholdMember: vi.fn().mockResolvedValue(null),
      removeHouseholdMember: vi.fn().mockResolvedValue(true),
      changeHouseholdMemberRole: vi.fn().mockResolvedValue(null),
      listHouseholds: vi.fn().mockResolvedValue({ households: [] }),
      getHouseholdMembers: vi.fn().mockResolvedValue({ members: [] }),
      updateHousehold: vi.fn().mockResolvedValue({ household: null }),
      getHouseholdMemberCount: vi.fn().mockResolvedValue(0),
    } as GuardedHouseholdServiceMockType;

    return mockService;
  }

  /**
   * Creates a GuardedHouseholdService mock that simulates successful operations
   * Returns mock household data for all operations
   */
  static createSuccessfulGuardedHouseholdServiceMock(
    mockHousehold?: Partial<HouseholdRecord>,
    mockMember?: Partial<HouseholdMemberRecord>,
  ): GuardedHouseholdServiceMockType {
    const defaultHousehold: HouseholdRecord = {
      id: 'test-household-id',
      name: 'Test Household',
      description: 'Test household description',
      created_by: 'test-user-id',
      created_at: new Date(),
      updated_at: new Date(),
    };

    const defaultMember: HouseholdMemberRecord = {
      id: 'test-member-id',
      household_id: 'test-household-id',
      user_id: 'test-user-id',
      role: 'member',
      joined_at: new Date(),
    };

    const household = mockHousehold
      ? { ...defaultHousehold, ...mockHousehold }
      : defaultHousehold;
    const member = mockMember
      ? { ...defaultMember, ...mockMember }
      : defaultMember;
    const mockService = this.createGuardedHouseholdServiceMock();

    mockService.createHousehold.mockResolvedValue({ household });
    mockService.getHousehold.mockResolvedValue({ household });
    mockService.addHouseholdMember.mockResolvedValue(member);
    mockService.removeHouseholdMember.mockResolvedValue(true);
    mockService.changeHouseholdMemberRole.mockResolvedValue(member);
    mockService.listHouseholds.mockResolvedValue({ households: [household] });
    mockService.getHouseholdMembers.mockResolvedValue({ members: [member] });
    mockService.updateHousehold.mockResolvedValue({ household });
    mockService.getHouseholdMemberCount.mockResolvedValue(3);

    return mockService;
  }

  /**
   * Creates a GuardedHouseholdService mock that simulates service failures
   * All methods throw errors
   */
  static createFailingGuardedHouseholdServiceMock(
    error?: Error,
  ): GuardedHouseholdServiceMockType {
    const defaultError = error || new Error('GuardedHouseholdService error');
    const mockService = this.createGuardedHouseholdServiceMock();

    mockService.createHousehold.mockRejectedValue(defaultError);
    mockService.getHousehold.mockRejectedValue(defaultError);
    mockService.addHouseholdMember.mockRejectedValue(defaultError);
    mockService.removeHouseholdMember.mockRejectedValue(defaultError);
    mockService.changeHouseholdMemberRole.mockRejectedValue(defaultError);
    mockService.listHouseholds.mockRejectedValue(defaultError);
    mockService.getHouseholdMembers.mockRejectedValue(defaultError);
    mockService.updateHousehold.mockRejectedValue(defaultError);
    mockService.getHouseholdMemberCount.mockRejectedValue(defaultError);

    return mockService;
  }

  /**
   * Creates a typed GuardedHouseholdService mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedGuardedHouseholdServiceMock(
    mockHousehold?: Partial<HouseholdRecord>,
    mockMember?: Partial<HouseholdMemberRecord>,
  ): GuardedHouseholdService {
    const mockService =
      mockHousehold || mockMember
        ? this.createSuccessfulGuardedHouseholdServiceMock(
            mockHousehold,
            mockMember,
          )
        : this.createGuardedHouseholdServiceMock();

    return mockService as unknown as GuardedHouseholdService;
  }
}
