import { vi } from 'vitest';
import type {
  HouseholdRepository,
  HouseholdRecord,
  HouseholdMemberRecord,
} from '../../modules/household/household.types.js';

// Define the mock type for HouseholdRepository following codebase patterns
export type HouseholdRepositoryMockType = {
  createHousehold: ReturnType<typeof vi.fn>;
  addHouseholdMember: ReturnType<typeof vi.fn>;
  getHouseholdById: ReturnType<typeof vi.fn>;
  getHouseholdByIdForUser: ReturnType<typeof vi.fn>;
  getHouseholdsForUser: ReturnType<typeof vi.fn>;
  removeHouseholdMember: ReturnType<typeof vi.fn>;
  getHouseholdMember: ReturnType<typeof vi.fn>;
  getHouseholdMembers: ReturnType<typeof vi.fn>;
  updateHouseholdMemberRole: ReturnType<typeof vi.fn>;
};

/**
 * HouseholdRepository mock factory for consistent testing
 * Follows the same pattern as other repository mocks in the codebase
 */
export class HouseholdRepositoryMock {
  /**
   * Creates a mock HouseholdRepository for testing
   * By default, all methods return null or reject
   */
  static createHouseholdRepositoryMock(): HouseholdRepositoryMockType {
    const mockRepository = {
      createHousehold: vi.fn().mockResolvedValue(null),
      addHouseholdMember: vi.fn().mockResolvedValue(null),
      getHouseholdById: vi.fn().mockResolvedValue(null),
      getHouseholdByIdForUser: vi.fn().mockResolvedValue(null),
      getHouseholdsForUser: vi.fn().mockResolvedValue([]),
      removeHouseholdMember: vi.fn().mockResolvedValue(null),
      getHouseholdMember: vi.fn().mockResolvedValue(null),
      getHouseholdMembers: vi.fn().mockResolvedValue([]),
      updateHouseholdMemberRole: vi.fn().mockResolvedValue(null),
    } as HouseholdRepositoryMockType;

    return mockRepository;
  }

  /**
   * Creates a HouseholdRepository mock that simulates successful operations
   * Returns mock household data for all operations
   */
  static createSuccessfulHouseholdRepositoryMock(
    mockHousehold?: Partial<HouseholdRecord>,
    mockMember?: Partial<HouseholdMemberRecord>,
  ): HouseholdRepositoryMockType {
    const defaultHousehold: HouseholdRecord = {
      id: 'test-household-id',
      name: 'Test Household',
      description: 'A test household',
      created_by: 'test-user-id',
      created_at: new Date(),
      updated_at: new Date(),
    };

    const defaultMember: HouseholdMemberRecord = {
      id: 'test-member-id',
      household_id: 'test-household-id',
      user_id: 'test-user-id',
      role: 'manager',
      joined_at: new Date(),
    };

    const household = mockHousehold
      ? { ...defaultHousehold, ...mockHousehold }
      : defaultHousehold;
    const member = mockMember
      ? { ...defaultMember, ...mockMember }
      : defaultMember;
    const mockRepository = this.createHouseholdRepositoryMock();

    mockRepository.createHousehold.mockResolvedValue(household);
    mockRepository.addHouseholdMember.mockResolvedValue(member);
    mockRepository.getHouseholdById.mockResolvedValue(household);
    mockRepository.getHouseholdByIdForUser.mockResolvedValue(household);
    mockRepository.getHouseholdsForUser.mockResolvedValue([household]);
    mockRepository.removeHouseholdMember.mockResolvedValue(member);
    mockRepository.getHouseholdMember.mockResolvedValue(member);
    mockRepository.getHouseholdMembers.mockResolvedValue([member]);
    mockRepository.updateHouseholdMemberRole.mockResolvedValue(member);

    return mockRepository;
  }

  /**
   * Creates a HouseholdRepository mock that simulates repository failures
   * All methods throw errors
   */
  static createFailingHouseholdRepositoryMock(
    error?: Error,
  ): HouseholdRepositoryMockType {
    const defaultError = error || new Error('HouseholdRepository error');
    const mockRepository = this.createHouseholdRepositoryMock();

    mockRepository.createHousehold.mockRejectedValue(defaultError);
    mockRepository.addHouseholdMember.mockRejectedValue(defaultError);
    mockRepository.getHouseholdById.mockRejectedValue(defaultError);
    mockRepository.getHouseholdByIdForUser.mockRejectedValue(defaultError);
    mockRepository.getHouseholdsForUser.mockRejectedValue(defaultError);
    mockRepository.removeHouseholdMember.mockRejectedValue(defaultError);
    mockRepository.getHouseholdMember.mockRejectedValue(defaultError);
    mockRepository.getHouseholdMembers.mockRejectedValue(defaultError);
    mockRepository.updateHouseholdMemberRole.mockRejectedValue(defaultError);

    return mockRepository;
  }

  /**
   * Creates a typed HouseholdRepository mock that can be used with dependency injection
   * Includes type assertion for use in NestJS test modules
   */
  static createTypedHouseholdRepositoryMock(
    mockHousehold?: Partial<HouseholdRecord>,
    mockMember?: Partial<HouseholdMemberRecord>,
  ): HouseholdRepository {
    const mockRepository =
      mockHousehold || mockMember
        ? this.createSuccessfulHouseholdRepositoryMock(
            mockHousehold,
            mockMember,
          )
        : this.createHouseholdRepositoryMock();

    return mockRepository as unknown as HouseholdRepository;
  }
}
