import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HouseholdServiceImpl } from '../household.service.js';
import { HouseholdRole } from '../../../common/enums.js';
import { TOKENS } from '../../../common/tokens.js';
import type { HouseholdRecord } from '../household.types.js';

// Mock repository
const mockHouseholdRepository = {
  createHousehold: vi.fn(),
  addHouseholdMember: vi.fn(),
  getHouseholdById: vi.fn(),
  getHouseholdByIdForUser: vi.fn(),
  getHouseholdsForUser: vi.fn(),
  getHouseholdMember: vi.fn(),
  removeHouseholdMember: vi.fn(),
  getHouseholdMembers: vi.fn(),
  updateHouseholdMemberRole: vi.fn(),
};

// Mock user service
const mockUserService = {
  getUserByAuthId: vi.fn(),
  getUserById: vi.fn(),
  updateUser: vi.fn(),
  createUser: vi.fn(),
  createAIUser: vi.fn(),
};

// Mock event emitter
const mockEventEmitter = {
  emit: vi.fn(),
};

describe('HouseholdService', () => {
  let householdService: HouseholdServiceImpl;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        HouseholdServiceImpl,
        {
          provide: TOKENS.HOUSEHOLD.REPOSITORY,
          useValue: mockHouseholdRepository,
        },
        {
          provide: TOKENS.USER.SERVICE,
          useValue: mockUserService,
        },
        {
          provide: EventEmitter2,
          useValue: mockEventEmitter,
        },
      ],
    }).compile();

    householdService = module.get<HouseholdServiceImpl>(HouseholdServiceImpl);

    // Reset all mocks
    vi.clearAllMocks();
  });

  describe('createHousehold', () => {
    it('should create household and add creator as manager', async () => {
      // Arrange
      const householdData = {
        id: 'household-123',
        name: 'Test Family',
        description: 'A test household',
      };
      const creatorId = 'user-456';

      const createdHousehold: HouseholdRecord = {
        id: 'household-123',
        name: 'Test Family',
        description: 'A test household',
        created_by: creatorId,
        created_at: new Date(),
        updated_at: new Date(),
      };

      const createdAIUser = {
        id: 'ai-user-789',
        auth_user_id: null,
        email: `ai-assistant+household-123@system.internal`,
        first_name: 'Pantry',
        last_name: 'Assistant',
        display_name: 'Pantry Assistant',
        avatar_url: '/avatars/default-ai-assistant.png',
        phone: null,
        birth_date: null,
        preferences: {
          ai_model: 'gpt-4',
          response_style: 'helpful',
          household_context: 'household-123',
        },
        managed_by: null,
        relationship_to_manager: null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockHouseholdRepository.createHousehold.mockResolvedValue(
        createdHousehold,
      );

      // Mock for creator member addition (called via addHouseholdMember service method)
      mockHouseholdRepository.getHouseholdMember.mockResolvedValue(null); // No existing member
      mockHouseholdRepository.addHouseholdMember
        .mockResolvedValueOnce({
          id: 'member-1',
          household_id: 'household-123',
          user_id: creatorId,
          role: HouseholdRole.MANAGER,
          joined_at: new Date(),
        })
        .mockResolvedValueOnce({
          id: 'member-2',
          household_id: 'household-123',
          user_id: 'ai-user-789',
          role: HouseholdRole.AI,
          joined_at: new Date(),
        });

      mockUserService.createAIUser.mockResolvedValue(createdAIUser);

      // Act
      const result = await householdService.createHousehold(
        householdData,
        creatorId,
      );

      // Assert
      expect(result).toEqual(createdHousehold);

      // Verify household creation
      expect(mockHouseholdRepository.createHousehold).toHaveBeenCalledWith({
        ...householdData,
        created_by: creatorId,
      });

      // Verify creator added as manager (via service method)
      expect(mockHouseholdRepository.addHouseholdMember).toHaveBeenCalledWith(
        expect.objectContaining({
          household_id: 'household-123',
          user_id: creatorId,
          role: HouseholdRole.MANAGER,
        }),
      );

      // Verify AI user creation (now via user service)
      expect(mockUserService.createAIUser).toHaveBeenCalledWith(
        expect.objectContaining({
          email: `ai-assistant+household-123@system.internal`,
        }),
      );

      // Verify AI user added as ai role (via service method)
      expect(mockHouseholdRepository.addHouseholdMember).toHaveBeenCalledWith(
        expect.objectContaining({
          household_id: 'household-123',
          user_id: 'ai-user-789',
          role: HouseholdRole.AI,
        }),
      );

      // Verify events emitted
      expect(mockEventEmitter.emit).toHaveBeenCalledWith(
        'household.member.added',
        expect.any(Object),
      );
      expect(mockEventEmitter.emit).toHaveBeenCalledWith(
        'user.permissions.recompute',
        expect.any(Object),
      );
      expect(mockEventEmitter.emit).toHaveBeenCalledWith(
        'household.created',
        expect.any(Object),
      );
    });

    it('should handle errors gracefully', async () => {
      // Arrange
      const householdData = {
        name: 'Test Family',
        description: 'A test household',
      };
      const creatorId = 'user-456';

      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});

      mockHouseholdRepository.createHousehold.mockRejectedValue(
        new Error('Database error'),
      );

      // Act & Assert
      await expect(
        householdService.createHousehold(householdData, creatorId),
      ).rejects.toThrow('Database error');

      expect(errorSpy).toHaveBeenCalledWith(
        'Failed to create household:',
        expect.any(Error),
      );

      errorSpy.mockRestore();
    });

    it('should log progress throughout the creation process', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});

      const householdData = {
        name: 'Test Family',
      };
      const creatorId = 'user-456';

      const createdHousehold: HouseholdRecord = {
        id: 'household-123',
        name: 'Test Family',
        description: null,
        created_by: creatorId,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockHouseholdRepository.createHousehold.mockResolvedValue(
        createdHousehold,
      );
      mockHouseholdRepository.getHouseholdMember.mockResolvedValue(null); // No existing member
      mockHouseholdRepository.addHouseholdMember
        .mockResolvedValueOnce({
          id: 'member-1',
          household_id: 'household-123',
          user_id: creatorId,
          role: HouseholdRole.MANAGER,
          joined_at: new Date(),
        })
        .mockResolvedValueOnce({
          id: 'member-2',
          household_id: 'household-123',
          user_id: 'ai-user-789',
          role: HouseholdRole.AI,
          joined_at: new Date(),
        });
      mockUserService.createAIUser.mockResolvedValue({
        id: 'ai-user-789',
        auth_user_id: null,
        email: `ai-assistant+household-123@system.internal`,
        first_name: 'Pantry',
        last_name: 'Assistant',
        display_name: 'Pantry Assistant',
        avatar_url: '/avatars/default-ai-assistant.png',
        phone: null,
        birth_date: null,
        preferences: null,
        managed_by: null,
        relationship_to_manager: null,
        created_at: new Date(),
        updated_at: new Date(),
      });

      // Act
      await householdService.createHousehold(householdData, creatorId);

      // Assert - verify logging calls
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          'Creating household: Test Family for creator user-456',
        ),
      );
      expect(logSpy).toHaveBeenCalledWith('Household created: household-123');
      expect(logSpy).toHaveBeenCalledWith(
        'Created AI user ai-user-789 for household household-123',
      );
      expect(logSpy).toHaveBeenCalledWith(
        'Household creation completed successfully: household-123',
      );

      // Note: Member addition logs are now generated by the addHouseholdMember service method

      logSpy.mockRestore();
    });
  });

  describe('getHouseholdMembers', () => {
    it('should get household members when user has access', async () => {
      // Arrange
      const householdId = 'household-123';
      const userId = 'user-456';
      const household: HouseholdRecord = {
        id: householdId,
        name: 'Test Family',
        description: 'A test household',
        created_by: userId,
        created_at: new Date(),
        updated_at: new Date(),
      };
      const members = [
        {
          id: 'member-1',
          household_id: householdId,
          user_id: userId,
          role: HouseholdRole.MANAGER,
          joined_at: new Date(),
        },
        {
          id: 'member-2',
          household_id: householdId,
          user_id: 'user-789',
          role: HouseholdRole.MEMBER,
          joined_at: new Date(),
        },
      ];

      mockHouseholdRepository.getHouseholdByIdForUser.mockResolvedValue(
        household,
      );
      mockHouseholdRepository.getHouseholdMembers.mockResolvedValue(members);

      // Act
      const result = await householdService.getHouseholdMembers(
        householdId,
        userId,
      );

      // Assert
      expect(result).toEqual(members);
      expect(
        mockHouseholdRepository.getHouseholdByIdForUser,
      ).toHaveBeenCalledWith(householdId, userId);
      expect(mockHouseholdRepository.getHouseholdMembers).toHaveBeenCalledWith(
        householdId,
      );
    });

    it('should throw NotFoundException when household is not found or user has no access', async () => {
      // Arrange
      const householdId = 'household-123';
      const userId = 'user-456';

      mockHouseholdRepository.getHouseholdByIdForUser.mockResolvedValue(null);

      // Act & Assert
      await expect(
        householdService.getHouseholdMembers(householdId, userId),
      ).rejects.toThrow('Household not found');

      expect(
        mockHouseholdRepository.getHouseholdByIdForUser,
      ).toHaveBeenCalledWith(householdId, userId);
      expect(
        mockHouseholdRepository.getHouseholdMembers,
      ).not.toHaveBeenCalled();
    });

    it('should handle repository errors gracefully', async () => {
      // Arrange
      const householdId = 'household-123';
      const userId = 'user-456';
      const error = new Error('Database connection failed');

      mockHouseholdRepository.getHouseholdByIdForUser.mockRejectedValue(error);

      // Act & Assert
      await expect(
        householdService.getHouseholdMembers(householdId, userId),
      ).rejects.toThrow('Database connection failed');

      expect(
        mockHouseholdRepository.getHouseholdByIdForUser,
      ).toHaveBeenCalledWith(householdId, userId);
    });
  });
});
