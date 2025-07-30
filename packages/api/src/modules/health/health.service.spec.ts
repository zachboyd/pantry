import { describe, it, expect, beforeEach } from 'vitest';
import { Test } from '@nestjs/testing';
import { HealthServiceImpl } from './health.service.js';
import { TOKENS } from '../../common/tokens.js';
import type { HealthService, HealthResponse } from './health.types.js';

describe('HealthService', () => {
  let healthService: HealthService;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        {
          provide: TOKENS.HEALTH.SERVICE,
          useClass: HealthServiceImpl,
        },
      ],
    }).compile();

    healthService = module.get<HealthService>(TOKENS.HEALTH.SERVICE);
  });

  describe('getHealth', () => {
    it('should return health status with ok status', () => {
      // Act
      const result = healthService.getHealth();

      // Assert
      expect(result).toBeDefined();
      expect(result.status).toBe('ok');
      expect(result.timestamp).toBeDefined();
    });

    it('should return valid ISO timestamp', () => {
      // Act
      const result = healthService.getHealth();

      // Assert
      expect(result.timestamp).toMatch(
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/,
      );
      expect(new Date(result.timestamp)).toBeInstanceOf(Date);
      expect(new Date(result.timestamp).getTime()).not.toBeNaN();
    });

    it('should return fresh timestamp on each call', async () => {
      // Arrange - Add small delay to ensure different timestamps
      const firstResult = healthService.getHealth();

      // Wait 2ms to ensure different timestamps (1ms might not be enough)
      await new Promise((resolve) => setTimeout(resolve, 2));

      const secondResult = healthService.getHealth();

      // Assert
      expect(firstResult.timestamp).not.toBe(secondResult.timestamp);
      expect(new Date(secondResult.timestamp).getTime()).toBeGreaterThanOrEqual(
        new Date(firstResult.timestamp).getTime(),
      );
    });

    it('should return consistent structure', () => {
      // Act
      const result = healthService.getHealth();

      // Assert
      expect(Object.keys(result)).toEqual(['status', 'timestamp']);
      expect(typeof result.status).toBe('string');
      expect(typeof result.timestamp).toBe('string');
    });

    it('should conform to HealthResponse interface', () => {
      // Act
      const result: HealthResponse = healthService.getHealth();

      // Assert - TypeScript compilation confirms interface compliance
      expect(result.status).toBeDefined();
      expect(result.timestamp).toBeDefined();
    });
  });
});
