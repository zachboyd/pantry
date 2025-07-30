import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { MessageServiceImpl } from './message.service.js';
import { TOKENS } from '../../common/tokens.js';
import { DatabaseFixtures } from '../../test/fixtures/database-fixtures.js';
import {
  EventEmitterMock,
  type EventEmitter2Mock,
} from '../../test/mocks/event-emitter.mock.js';
import {
  MessageRepositoryMock,
  type MessageRepositoryMockType,
} from '../../test/mocks/message-repository.mock.js';

describe('MessageService', () => {
  let messageService: MessageServiceImpl;
  let mockMessageRepository: MessageRepositoryMockType;
  let mockEventEmitter: EventEmitter2Mock;

  beforeEach(async () => {
    // Create mocks
    mockMessageRepository = MessageRepositoryMock.createMessageRepositoryMock();
    mockEventEmitter = EventEmitterMock.createEventEmitterMock();

    // Create test module
    const module = await Test.createTestingModule({
      providers: [
        MessageServiceImpl,
        {
          provide: TOKENS.MESSAGE.REPOSITORY,
          useValue: mockMessageRepository,
        },
        {
          provide: EventEmitter2,
          useValue: mockEventEmitter,
        },
      ],
    }).compile();

    messageService = module.get<MessageServiceImpl>(MessageServiceImpl);

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  describe('save', () => {
    it('should save a message successfully', async () => {
      // Arrange
      const messageToSave = DatabaseFixtures.createMessage({
        content: 'Test message',
        household_id: 'test-household-id',
        user_id: 'test-user-id',
        message_type: 'text',
      });

      const savedMessage = DatabaseFixtures.createMessageResult({
        id: 'saved-message-id',
        content: 'Test message',
        household_id: 'test-household-id',
        user_id: 'test-user-id',
        message_type: 'text',
      });

      mockMessageRepository.save.mockResolvedValue(savedMessage);

      // Act
      const result = await messageService.save(messageToSave);

      // Assert
      expect(result).toEqual(savedMessage);
      expect(mockMessageRepository.save).toHaveBeenCalledWith(messageToSave);

      // Note: Event emission tested separately due to setImmediate timing
    });

    it('should call repository save method with correct parameters', async () => {
      // Arrange
      const messageInput = DatabaseFixtures.createMessage({
        content: 'Test content',
        household_id: 'household-123',
        user_id: 'user-456',
        message_type: 'text',
      });
      const savedMessage = DatabaseFixtures.createMessageResult({
        id: messageInput.id,
      });

      mockMessageRepository.save.mockResolvedValue(savedMessage);

      // Act
      await messageService.save(messageInput);

      // Assert
      expect(mockMessageRepository.save).toHaveBeenCalledTimes(1);
      expect(mockMessageRepository.save).toHaveBeenCalledWith(messageInput);
    });

    it('should handle repository errors gracefully', async () => {
      // Arrange
      const messageInput = DatabaseFixtures.createMessage();
      const repositoryError = new Error('Repository failed');

      mockMessageRepository.save.mockRejectedValue(repositoryError);

      // Act & Assert
      await expect(messageService.save(messageInput)).rejects.toThrow(
        repositoryError,
      );
      expect(mockMessageRepository.save).toHaveBeenCalledWith(messageInput);

      // Should not emit event if save failed
      await new Promise(setImmediate);
      expect(mockEventEmitter.emit).not.toHaveBeenCalled();
    });

    it('should preserve message metadata when saving', async () => {
      // Arrange
      const messageInput = DatabaseFixtures.createMessage({
        metadata: { test: 'data', source: 'api' },
      });
      const savedMessage = DatabaseFixtures.createMessageResult({
        id: messageInput.id,
        metadata: messageInput.metadata,
      });

      mockMessageRepository.save.mockResolvedValue(savedMessage);

      // Act
      const result = await messageService.save(messageInput);

      // Assert
      expect(result).toEqual(savedMessage);
      expect(mockMessageRepository.save).toHaveBeenCalledWith(
        expect.objectContaining({
          metadata: { test: 'data', source: 'api' },
        }),
      );
    });

    it('should handle different message types', async () => {
      // Arrange
      const aiMessage = DatabaseFixtures.createMessage({
        message_type: 'ai',
        user_id: 'ai-user-id',
      });
      const savedMessage = DatabaseFixtures.createMessageResult({
        id: aiMessage.id,
        message_type: 'ai',
        user_id: 'ai-user-id',
      });

      mockMessageRepository.save.mockResolvedValue(savedMessage);

      // Act
      const result = await messageService.save(aiMessage);

      // Assert
      expect(result).toEqual(savedMessage);
      expect(mockMessageRepository.save).toHaveBeenCalledWith(aiMessage);

      // Repository should be called regardless of message type
    });
  });
});
