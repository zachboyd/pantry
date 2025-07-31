import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { HouseholdServiceImpl } from './household.service.js';
import { TOKENS } from '../../common/tokens.js';
import type { HouseholdRepository, HouseholdRecord } from './household.types.js';

// Mock repository
const mockHouseholdRepository = {
  createHousehold: vi.fn(),
  addHouseholdMember: vi.fn(),
  getHouseholdById: vi.fn(),
  getHouseholdsForUser: vi.fn(),
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

      mockHouseholdRepository.createHousehold.mockResolvedValue(createdHousehold);
      mockHouseholdRepository.addHouseholdMember.mockResolvedValue({
        id: 'member-1',
        household_id: 'household-123',
        user_id: creatorId,
        role: 'manager',
        joined_at: new Date(),
      });
      mockHouseholdRepository.createAIUser.mockResolvedValue(createdAIUser);

      // Act
      const result = await householdService.createHousehold(householdData, creatorId);

      // Assert
      expect(result).toEqual(createdHousehold);

      // Verify household creation
      expect(mockHouseholdRepository.createHousehold).toHaveBeenCalledWith({
        ...householdData,
        created_by: creatorId,
      });

      // Verify creator added as manager
      expect(mockHouseholdRepository.addHouseholdMember).toHaveBeenCalledWith(
        expect.objectContaining({
          household_id: 'household-123',
          user_id: creatorId,
          role: 'manager',
        }),
      );

      // Verify AI user creation (implicit behavior)
      expect(mockHouseholdRepository.createAIUser).toHaveBeenCalledWith(
        expect.objectContaining({
          auth_user_id: null,
          first_name: 'Pantry',
          last_name: 'Assistant',
          display_name: expect.stringMatching(/^(Alfred|Alice|Rosey) - Pantry Assistant$/),
          preferences: {
            personality: expect.stringMatching(/^(Alfred|Alice|Rosey)$/),
          },
        }),
      );

      // Verify AI user added as ai role (implicit behavior)
      expect(mockHouseholdRepository.addHouseholdMember).toHaveBeenCalledWith(
        expect.objectContaining({
          household_id: 'household-123',
          user_id: 'ai-user-789',
          role: 'ai',
        }),
      );

      // Verify event emission
      expect(mockEventEmitter.emit).toHaveBeenCalledWith('household.created', {
        household: createdHousehold,
        creator: creatorId,
        aiUser: createdAIUser,
      });
    });

    it('should handle errors gracefully', async () => {
      // Arrange
      const householdData = {
        name: 'Test Family',
        description: 'A test household',
      };
      const creatorId = 'user-456';

      const errorSpy = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
      
      mockHouseholdRepository.createHousehold.mockRejectedValue(new Error('Database error'));

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
      const logSpy = vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});

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

      mockHouseholdRepository.createHousehold.mockResolvedValue(createdHousehold);
      mockHouseholdRepository.addHouseholdMember.mockResolvedValue({
        id: 'member-1',
        household_id: 'household-123',
        user_id: creatorId,
        role: 'manager',
        joined_at: new Date(),
      });
      mockHouseholdRepository.createAIUser.mockResolvedValue({
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
        expect.stringContaining('Creating household: Test Family for creator user-456'),
      );
      expect(logSpy).toHaveBeenCalledWith('Household created: household-123');
      expect(logSpy).toHaveBeenCalledWith(
        'Added creator user-456 as manager to household household-123',
      );
      expect(logSpy).toHaveBeenCalledWith(
        'Created AI user ai-user-789 for household household-123',
      );
      expect(logSpy).toHaveBeenCalledWith(
        'Added AI user ai-user-789 as ai to household household-123',
      );
      expect(logSpy).toHaveBeenCalledWith(
        'Household creation completed successfully: household-123',
      );

      logSpy.mockRestore();
    });
  });
});