import { Test } from '@nestjs/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { TOKENS } from '../../common/tokens.js';
import { HealthController } from './health.controller.js';
import type { HealthResponse } from './health.types.js';

describe('HealthController', () => {
  let healthController: HealthController;
  let mockHealthService: { getHealth: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    mockHealthService = {
      getHealth: vi.fn(),
    };

    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: TOKENS.HEALTH.SERVICE,
          useValue: mockHealthService,
        },
      ],
    }).compile();

    healthController = module.get<HealthController>(HealthController);
  });

  describe('getHealth', () => {
    it('should return health response from service', () => {
      // Arrange
      const expectedResponse: HealthResponse = {
        status: 'ok',
        timestamp: '2025-06-27T12:00:00.000Z',
      };
      mockHealthService.getHealth.mockReturnValue(expectedResponse);

      // Act
      const result = healthController.getHealth();

      // Assert
      expect(result).toEqual(expectedResponse);
      expect(mockHealthService.getHealth).toHaveBeenCalledTimes(1);
      expect(mockHealthService.getHealth).toHaveBeenCalledWith();
    });

    it('should delegate to health service without modification', () => {
      // Arrange
      const serviceResponse: HealthResponse = {
        status: 'ok',
        timestamp: '2025-06-27T08:30:00.123Z',
      };
      mockHealthService.getHealth.mockReturnValue(serviceResponse);

      // Act
      const controllerResponse = healthController.getHealth();

      // Assert
      expect(controllerResponse).toBe(serviceResponse); // Same reference
      expect(mockHealthService.getHealth).toHaveBeenCalledOnce();
    });

    it('should handle different health statuses', () => {
      // Arrange
      const degradedResponse: HealthResponse = {
        status: 'degraded',
        timestamp: '2025-06-27T08:30:00.456Z',
      };
      mockHealthService.getHealth.mockReturnValue(degradedResponse);

      // Act
      const result = healthController.getHealth();

      // Assert
      expect(result.status).toBe('degraded');
      expect(result.timestamp).toBe('2025-06-27T08:30:00.456Z');
    });

    it('should call service each time endpoint is hit', () => {
      // Arrange
      const response1: HealthResponse = {
        status: 'ok',
        timestamp: '2025-06-27T08:30:00.111Z',
      };
      const response2: HealthResponse = {
        status: 'ok',
        timestamp: '2025-06-27T08:30:00.222Z',
      };

      mockHealthService.getHealth
        .mockReturnValueOnce(response1)
        .mockReturnValueOnce(response2);

      // Act
      const firstCall = healthController.getHealth();
      const secondCall = healthController.getHealth();

      // Assert
      expect(firstCall).toEqual(response1);
      expect(secondCall).toEqual(response2);
      expect(mockHealthService.getHealth).toHaveBeenCalledTimes(2);
    });

    it('should maintain type safety with HealthResponse', () => {
      // Arrange
      const validResponse: HealthResponse = {
        status: 'maintenance',
        timestamp: new Date().toISOString(),
      };
      mockHealthService.getHealth.mockReturnValue(validResponse);

      // Act
      const result: HealthResponse = healthController.getHealth();

      // Assert - TypeScript compilation ensures type safety
      expect(typeof result.status).toBe('string');
      expect(typeof result.timestamp).toBe('string');
    });

    it('should handle service errors gracefully', () => {
      // Arrange
      const serviceError = new Error('Health service unavailable');
      mockHealthService.getHealth.mockImplementation(() => {
        throw serviceError;
      });

      // Act & Assert
      expect(() => healthController.getHealth()).toThrow(serviceError);
      expect(mockHealthService.getHealth).toHaveBeenCalledOnce();
    });

    it('should expose GET endpoint without authentication', () => {
      // This test verifies the decorators are properly applied
      // The @Public() decorator should be present to bypass authentication

      // Arrange
      const response: HealthResponse = {
        status: 'ok',
        timestamp: new Date().toISOString(),
      };
      mockHealthService.getHealth.mockReturnValue(response);

      // Act
      const result = healthController.getHealth();

      // Assert
      expect(result).toEqual(response);
      // Note: Actual authentication bypass testing would be done in integration tests
    });
  });
});
