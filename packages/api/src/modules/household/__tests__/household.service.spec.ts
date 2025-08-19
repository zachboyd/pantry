import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HouseholdServiceImpl } from '../household.service.js';
import { HouseholdRole } from '../../../common/enums.js';
import { TOKENS } from '../../../common/tokens.js';
import type { HouseholdRecord } from '../household.types.js';
import {
  HouseholdRepositoryMock,
  type HouseholdRepositoryMockType,
} from '../../../test/mocks/household-repository.mock.js';
import {
  UserServiceMock,
  type UserServiceMockType,
} from '../../../test/mocks/user-service.mock.js';
import {
  EventEmitterMock,
  type EventEmitter2Mock,
} from '../../../test/mocks/event-emitter.mock.js';
import { DatabaseFixtures } from '../../../test/fixtures/database-fixtures.js';

describe('HouseholdService', () => {
  let householdService: HouseholdServiceImpl;
  let mockHouseholdRepository: HouseholdRepositoryMockType;
  let mockUserService: UserServiceMockType;
  let mockEventEmitter: EventEmitter2Mock;

  beforeEach(async () => {
    // Create mocks
    mockHouseholdRepository =
      HouseholdRepositoryMock.createHouseholdRepositoryMock();
    mockUserService = UserServiceMock.createUserServiceMock();
    mockEventEmitter = EventEmitterMock.createEventEmitterMock();

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

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
        first_name: 'Jeeves',
        last_name: 'Assistant',
        display_name: 'Jeeves Assistant',
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
        expect.any(Error),
        'Failed to create household:',
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
        first_name: 'Jeeves',
        last_name: 'Assistant',
        display_name: 'Jeeves Assistant',
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

    it('should set created household as primary when user has no primary household', async () => {
      // Arrange
      const householdData = {
        id: 'household-123',
        name: 'Test Family',
        description: 'A test household',
      };
      const creatorId = 'user-456';

      const createdHousehold = DatabaseFixtures.createHouseholdRecord({
        id: 'household-123',
        name: 'Test Family',
        description: 'A test household',
        created_by: creatorId,
      });

      const creatorUser = DatabaseFixtures.createUserResult({
        id: creatorId,
        primary_household_id: null, // User has no primary household
      });

      const updatedUser = DatabaseFixtures.createUserResult({
        id: creatorId,
        primary_household_id: 'household-123', // Updated with primary household
      });

      const createdAIUser = DatabaseFixtures.createUserResult({
        id: 'ai-user-789',
        email: `ai-assistant+household-123@system.internal`,
        is_ai: true,
      });

      // Setup mocks
      mockHouseholdRepository.createHousehold.mockResolvedValue(
        createdHousehold,
      );
      mockHouseholdRepository.getHouseholdMember.mockResolvedValue(null);
      mockHouseholdRepository.addHouseholdMember
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-123',
            user_id: creatorId,
            role: HouseholdRole.MANAGER,
          }),
        )
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-123',
            user_id: 'ai-user-789',
            role: HouseholdRole.AI,
          }),
        );

      mockUserService.getUserById.mockResolvedValue(creatorUser);
      mockUserService.setPrimaryHousehold.mockResolvedValue(updatedUser);
      mockUserService.createAIUser.mockResolvedValue(createdAIUser);

      // Act
      const result = await householdService.createHousehold(
        householdData,
        creatorId,
      );

      // Assert
      expect(result).toEqual(createdHousehold);

      // Verify primary household was set
      expect(mockUserService.getUserById).toHaveBeenCalledWith(creatorId);
      expect(mockUserService.setPrimaryHousehold).toHaveBeenCalledWith(
        creatorId,
        'household-123',
      );
    });

    it('should not set primary household when user already has one', async () => {
      // Arrange
      const householdData = {
        id: 'household-456',
        name: 'Second Family',
        description: 'A second household',
      };
      const creatorId = 'user-789';

      const createdHousehold = DatabaseFixtures.createHouseholdRecord({
        id: 'household-456',
        name: 'Second Family',
        description: 'A second household',
        created_by: creatorId,
      });

      const creatorUser = DatabaseFixtures.createUserResult({
        id: creatorId,
        primary_household_id: 'existing-household-id', // User already has primary household
      });

      const createdAIUser = DatabaseFixtures.createUserResult({
        id: 'ai-user-123',
        email: `ai-assistant+household-456@system.internal`,
        is_ai: true,
      });

      // Setup mocks
      mockHouseholdRepository.createHousehold.mockResolvedValue(
        createdHousehold,
      );
      mockHouseholdRepository.getHouseholdMember.mockResolvedValue(null);
      mockHouseholdRepository.addHouseholdMember
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-456',
            user_id: creatorId,
            role: HouseholdRole.MANAGER,
          }),
        )
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-456',
            user_id: 'ai-user-123',
            role: HouseholdRole.AI,
          }),
        );

      mockUserService.getUserById.mockResolvedValue(creatorUser);
      mockUserService.createAIUser.mockResolvedValue(createdAIUser);

      // Act
      const result = await householdService.createHousehold(
        householdData,
        creatorId,
      );

      // Assert
      expect(result).toEqual(createdHousehold);

      // Verify primary household was NOT set (user already has one)
      expect(mockUserService.getUserById).toHaveBeenCalledWith(creatorId);
      expect(mockUserService.setPrimaryHousehold).not.toHaveBeenCalled();
    });

    it('should handle user not found gracefully when setting primary household', async () => {
      // Arrange
      const householdData = {
        id: 'household-789',
        name: 'Test Family',
        description: 'A test household',
      };
      const creatorId = 'user-nonexistent';

      const createdHousehold = DatabaseFixtures.createHouseholdRecord({
        id: 'household-789',
        name: 'Test Family',
        description: 'A test household',
        created_by: creatorId,
      });

      const createdAIUser = DatabaseFixtures.createUserResult({
        id: 'ai-user-456',
        email: `ai-assistant+household-789@system.internal`,
        is_ai: true,
      });

      // Setup mocks
      mockHouseholdRepository.createHousehold.mockResolvedValue(
        createdHousehold,
      );
      mockHouseholdRepository.getHouseholdMember.mockResolvedValue(null);
      mockHouseholdRepository.addHouseholdMember
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-789',
            user_id: creatorId,
            role: HouseholdRole.MANAGER,
          }),
        )
        .mockResolvedValueOnce(
          DatabaseFixtures.createHouseholdMemberRecord({
            household_id: 'household-789',
            user_id: 'ai-user-456',
            role: HouseholdRole.AI,
          }),
        );

      mockUserService.getUserById.mockResolvedValue(null); // User not found
      mockUserService.createAIUser.mockResolvedValue(createdAIUser);

      // Act
      const result = await householdService.createHousehold(
        householdData,
        creatorId,
      );

      // Assert
      expect(result).toEqual(createdHousehold);

      // Verify primary household was NOT set (user not found)
      expect(mockUserService.getUserById).toHaveBeenCalledWith(creatorId);
      expect(mockUserService.setPrimaryHousehold).not.toHaveBeenCalled();
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
