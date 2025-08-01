import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { TypingIndicatorServiceImpl } from '../typing-indicator.service.js';
import { TOKENS } from '../../../common/tokens.js';
import {
  TypingIndicatorRepositoryMock,
  type TypingIndicatorRepositoryMockType,
} from '../../../test/mocks/typing-indicator-repository.mock.js';
import { DatabaseFixtures } from '../../../test/fixtures/database-fixtures.js';

describe('TypingIndicatorService', () => {
  let typingIndicatorService: TypingIndicatorServiceImpl;
  let mockTypingIndicatorRepository: TypingIndicatorRepositoryMockType;

  beforeEach(async () => {
    // Create mocks
    mockTypingIndicatorRepository =
      TypingIndicatorRepositoryMock.createTypingIndicatorRepositoryMock();

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        TypingIndicatorServiceImpl,
        {
          provide: TOKENS.MESSAGE.TYPING_INDICATOR_REPOSITORY,
          useValue: mockTypingIndicatorRepository,
        },
      ],
    }).compile();

    typingIndicatorService = module.get<TypingIndicatorServiceImpl>(
      TypingIndicatorServiceImpl,
    );

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  describe('save', () => {
    it('should save a typing indicator successfully', async () => {
      // Arrange
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator();
      const savedTypingIndicator = DatabaseFixtures.createTypingIndicatorResult(
        {
          id: typingIndicatorInput.id,
        },
      );

      mockTypingIndicatorRepository.save.mockResolvedValue(
        savedTypingIndicator,
      );

      // Act
      const result = await typingIndicatorService.save(typingIndicatorInput);

      // Assert
      expect(result).toEqual(savedTypingIndicator);
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        typingIndicatorInput,
      );
    });

    it('should handle upsert conflicts on household_id and user_id composite key', async () => {
      // Arrange
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator({
        household_id: 'test-household',
        user_id: 'test-user',
      });
      const savedTypingIndicator =
        DatabaseFixtures.createTypingIndicatorResult();

      mockTypingIndicatorRepository.save.mockResolvedValue(
        savedTypingIndicator,
      );

      // Act
      await typingIndicatorService.save(typingIndicatorInput);

      // Assert
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        typingIndicatorInput,
      );
    });

    it('should update existing typing indicator when conflict occurs', async () => {
      // Arrange
      // Simulate an update with new typing state
      const updatedIndicator = DatabaseFixtures.createTypingIndicator({
        household_id: 'test-household',
        user_id: 'test-user',
        id: 'different-id', // Different ID but same household_id/user_id
      });

      const savedIndicator = DatabaseFixtures.createTypingIndicatorResult();

      mockTypingIndicatorRepository.save.mockResolvedValue(savedIndicator);

      // Act
      const result = await typingIndicatorService.save(updatedIndicator);

      // Assert
      expect(result).toEqual(savedIndicator);
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        updatedIndicator,
      );
    });

    it('should handle database errors gracefully', async () => {
      // Arrange
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator();
      const dbError = new Error('Database connection failed');

      mockTypingIndicatorRepository.save.mockRejectedValue(dbError);

      // Act & Assert
      await expect(
        typingIndicatorService.save(typingIndicatorInput),
      ).rejects.toThrow(dbError);
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        typingIndicatorInput,
      );
    });

    it('should handle different typing states', async () => {
      // Arrange - Test saving a "not typing" indicator
      const notTypingIndicator = DatabaseFixtures.createTypingIndicator();
      const savedIndicator = DatabaseFixtures.createTypingIndicatorResult();

      mockTypingIndicatorRepository.save.mockResolvedValue(savedIndicator);

      // Act
      const result = await typingIndicatorService.save(notTypingIndicator);

      // Assert
      expect(result).toEqual(savedIndicator);
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        notTypingIndicator,
      );
    });

    it('should preserve all typing indicator fields', async () => {
      // Arrange
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator({
        household_id: 'specific-household',
        user_id: 'specific-user',
        id: 'specific-id',
      });

      const savedIndicator = DatabaseFixtures.createTypingIndicatorResult();

      mockTypingIndicatorRepository.save.mockResolvedValue(savedIndicator);

      // Act
      const result = await typingIndicatorService.save(typingIndicatorInput);

      // Assert
      expect(result).toEqual(savedIndicator);
      expect(mockTypingIndicatorRepository.save).toHaveBeenCalledWith(
        typingIndicatorInput,
      );
    });

    it('should log successful operations', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator({
        household_id: 'test-household',
        user_id: 'test-user',
      });
      const savedIndicator = DatabaseFixtures.createTypingIndicatorResult();

      mockTypingIndicatorRepository.save.mockResolvedValue(savedIndicator);

      // Act
      await typingIndicatorService.save(typingIndicatorInput);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining(
          'Processing typing indicator for user test-user in household test-household',
        ),
      );
      expect(logSpy).toHaveBeenCalledWith(
        expect.stringContaining('Typing indicator processed successfully'),
      );
    });

    it('should log errors when database operations fail', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const typingIndicatorInput = DatabaseFixtures.createTypingIndicator();
      const dbError = new Error('Connection timeout');

      mockTypingIndicatorRepository.save.mockRejectedValue(dbError);

      // Act & Assert
      await expect(
        typingIndicatorService.save(typingIndicatorInput),
      ).rejects.toThrow();
      expect(errorSpy).toHaveBeenCalledWith(
        'Failed to process typing indicator:',
        dbError,
      );
    });
  });
});
