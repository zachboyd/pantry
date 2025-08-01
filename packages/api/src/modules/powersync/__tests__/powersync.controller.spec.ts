import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { UpdateType, CrudEntry } from '@powersync/common';
import { PowerSyncController } from '../powersync.controller.js';
import { TOKENS } from '../../../common/tokens.js';
import { DatabaseFixtures } from '../../../test/fixtures/database-fixtures.js';
import type {
  PowerSyncAuthService,
  PowerSyncOperationService,
  WriteBatchRequest,
  WriteBatchResponse,
  JwksResponse,
} from '../powersync.types.js';

describe('PowerSyncController', () => {
  let powerSyncController: PowerSyncController;
  let mockPowerSyncAuthService: {
    [K in keyof PowerSyncAuthService]: ReturnType<typeof vi.fn>;
  };
  let mockPowerSyncOperationService: {
    [K in keyof PowerSyncOperationService]: ReturnType<typeof vi.fn>;
  };

  beforeEach(async () => {
    mockPowerSyncAuthService = {
      generateToken: vi.fn(),
      verifyToken: vi.fn(),
      getJwks: vi.fn(),
      getExpirationSeconds: vi.fn(),
    };

    mockPowerSyncOperationService = {
      processOperation: vi.fn(),
      processOperations: vi.fn(),
    };

    const module = await Test.createTestingModule({
      controllers: [PowerSyncController],
      providers: [
        {
          provide: TOKENS.POWERSYNC.AUTH_SERVICE,
          useValue: mockPowerSyncAuthService,
        },
        {
          provide: TOKENS.POWERSYNC.OPERATION_SERVICE,
          useValue: mockPowerSyncOperationService,
        },
      ],
    }).compile();

    powerSyncController = module.get<PowerSyncController>(PowerSyncController);

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'debug').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
  });

  describe('authenticateForPowerSync', () => {
    it('should generate PowerSync token for valid user', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult({
        id: 'test-user-id',
        email: 'test@example.com',
      });
      const mockToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature';
      const beforeTimestamp = Math.floor(Date.now() / 1000);

      mockPowerSyncAuthService.generateToken.mockResolvedValue(mockToken);
      mockPowerSyncAuthService.getExpirationSeconds.mockReturnValue(300); // 5 minutes

      // Act
      const result = await powerSyncController.authenticateForPowerSync(user);

      // Assert
      expect(result.token).toBe(mockToken);
      expect(result.expires_at).toBeGreaterThanOrEqual(
        beforeTimestamp + 5 * 60 - 1,
      );
      expect(result.expires_at).toBeLessThanOrEqual(
        beforeTimestamp + 5 * 60 + 1,
      );
      expect(mockPowerSyncAuthService.generateToken).toHaveBeenCalledWith(user);
      expect(mockPowerSyncAuthService.generateToken).toHaveBeenCalledTimes(1);
    });

    it('should throw UnauthorizedException when user is null', async () => {
      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(null),
      ).rejects.toThrow(UnauthorizedException);
      await expect(
        powerSyncController.authenticateForPowerSync(null),
      ).rejects.toThrow('User not found');

      expect(mockPowerSyncAuthService.generateToken).not.toHaveBeenCalled();
    });

    it('should throw UnauthorizedException when user is undefined', async () => {
      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(undefined!),
      ).rejects.toThrow(UnauthorizedException);

      expect(mockPowerSyncAuthService.generateToken).not.toHaveBeenCalled();
    });

    it('should log successful token generation', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const user = DatabaseFixtures.createUserResult({ id: 'log-test-user' });
      mockPowerSyncAuthService.generateToken.mockResolvedValue('test-token');
      mockPowerSyncAuthService.getExpirationSeconds.mockReturnValue(300);

      // Act
      await powerSyncController.authenticateForPowerSync(user);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        'Generated PowerSync token for user log-test-user',
      );
    });

    it('should handle service errors and wrap in UnauthorizedException', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const serviceError = new Error('JWT generation failed');
      mockPowerSyncAuthService.generateToken.mockRejectedValue(serviceError);

      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow(UnauthorizedException);
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow('Authentication failed');
    });

    it('should preserve BadRequestException from service', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const badRequestError = new BadRequestException('Invalid user data');
      mockPowerSyncAuthService.generateToken.mockRejectedValue(badRequestError);

      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow(BadRequestException);
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow('Invalid user data');
    });

    it('should preserve UnauthorizedException from service', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const unauthorizedError = new UnauthorizedException('Invalid session');
      mockPowerSyncAuthService.generateToken.mockRejectedValue(
        unauthorizedError,
      );

      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow(UnauthorizedException);
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow('Invalid session');
    });

    it('should log errors when authentication fails', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const user = DatabaseFixtures.createUserResult();
      const serviceError = new Error('Token service down');
      mockPowerSyncAuthService.generateToken.mockRejectedValue(serviceError);

      // Act & Assert
      await expect(
        powerSyncController.authenticateForPowerSync(user),
      ).rejects.toThrow();

      expect(errorSpy).toHaveBeenCalledWith(
        serviceError,
        'PowerSync authentication failed',
      );
    });
  });

  describe('getJwks', () => {
    it('should return JWKS from auth service', async () => {
      // Arrange
      const mockJwks: JwksResponse = {
        keys: [
          {
            kty: 'RSA',
            kid: 'test-key-id',
            use: 'sig',
            n: 'test-modulus',
            e: 'AQAB',
          },
        ],
      };
      mockPowerSyncAuthService.getJwks.mockResolvedValue(mockJwks);

      // Act
      const result = await powerSyncController.getJwks();

      // Assert
      expect(result).toEqual(mockJwks);
      expect(mockPowerSyncAuthService.getJwks).toHaveBeenCalledTimes(1);
      expect(mockPowerSyncAuthService.getJwks).toHaveBeenCalledWith();
    });

    it('should log debug message when serving JWKS', async () => {
      // Arrange
      const debugSpy = vi
        .spyOn(Logger.prototype, 'debug')
        .mockImplementation(() => {});
      const mockJwks: JwksResponse = { keys: [] };
      mockPowerSyncAuthService.getJwks.mockResolvedValue(mockJwks);

      // Act
      await powerSyncController.getJwks();

      // Assert
      expect(debugSpy).toHaveBeenCalledWith('Served JWKS endpoint');
    });

    it('should handle and rethrow JWKS service errors', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const serviceError = new Error('JWKS service unavailable');
      mockPowerSyncAuthService.getJwks.mockRejectedValue(serviceError);

      // Act & Assert
      await expect(powerSyncController.getJwks()).rejects.toThrow(serviceError);
      expect(errorSpy).toHaveBeenCalledWith(
        serviceError,
        'Failed to serve JWKS',
      );
    });

    it('should return empty keys array when service returns empty', async () => {
      // Arrange
      const emptyJwks: JwksResponse = { keys: [] };
      mockPowerSyncAuthService.getJwks.mockResolvedValue(emptyJwks);

      // Act
      const result = await powerSyncController.getJwks();

      // Assert
      expect(result).toEqual(emptyJwks);
      expect(result.keys).toHaveLength(0);
    });
  });

  describe('processWriteOperations', () => {
    it('should process write operations successfully', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult({ id: 'write-user' });
      const operations: CrudEntry[] = [
        new CrudEntry(1, UpdateType.PUT, 'messages', 'msg-1', undefined, {
          content: 'Hello',
        }),
        new CrudEntry(2, UpdateType.DELETE, 'messages', 'msg-2'),
      ];
      const request: WriteBatchRequest = { operations };
      const expectedResponse: WriteBatchResponse = {
        success: true,
        errors: [],
      };

      mockPowerSyncOperationService.processOperations.mockResolvedValue(
        expectedResponse,
      );

      // Act
      const result = await powerSyncController.processWriteOperations(
        request,
        user,
      );

      // Assert
      expect(result).toEqual(expectedResponse);
      expect(
        mockPowerSyncOperationService.processOperations,
      ).toHaveBeenCalledWith(operations, user);
      expect(
        mockPowerSyncOperationService.processOperations,
      ).toHaveBeenCalledTimes(1);
    });

    it('should throw UnauthorizedException when user is null', async () => {
      // Arrange
      const request: WriteBatchRequest = { operations: [] };

      // Act & Assert
      await expect(
        powerSyncController.processWriteOperations(request, null),
      ).rejects.toThrow(UnauthorizedException);
      await expect(
        powerSyncController.processWriteOperations(request, null),
      ).rejects.toThrow('User not found');

      expect(
        mockPowerSyncOperationService.processOperations,
      ).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when operations is missing', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const invalidRequest = {} as WriteBatchRequest;

      // Act & Assert
      await expect(
        powerSyncController.processWriteOperations(invalidRequest, user),
      ).rejects.toThrow(BadRequestException);
      await expect(
        powerSyncController.processWriteOperations(invalidRequest, user),
      ).rejects.toThrow('Invalid request: operations array required');

      expect(
        mockPowerSyncOperationService.processOperations,
      ).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException when operations is not an array', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const invalidRequest = { operations: 'not-an-array' } as any;

      // Act & Assert
      await expect(
        powerSyncController.processWriteOperations(invalidRequest, user),
      ).rejects.toThrow(BadRequestException);

      expect(
        mockPowerSyncOperationService.processOperations,
      ).not.toHaveBeenCalled();
    });

    it('should log operation processing start and completion', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const user = DatabaseFixtures.createUserResult({ id: 'log-user' });
      const operations: CrudEntry[] = [
        new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
      ];
      const request: WriteBatchRequest = { operations };
      const response: WriteBatchResponse = { success: true };

      mockPowerSyncOperationService.processOperations.mockResolvedValue(
        response,
      );

      // Act
      await powerSyncController.processWriteOperations(request, user);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        'Processing 1 write operations for user log-user',
      );
      expect(logSpy).toHaveBeenCalledWith(
        'Completed write operations for user log-user: success',
      );
    });

    it('should log partial failure when operations partially succeed', async () => {
      // Arrange
      const logSpy = vi
        .spyOn(Logger.prototype, 'log')
        .mockImplementation(() => {});
      const user = DatabaseFixtures.createUserResult({ id: 'partial-user' });
      const request: WriteBatchRequest = {
        operations: [
          new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
        ],
      };
      const response: WriteBatchResponse = {
        success: false,
        errors: [
          {
            operation_id: 0,
            message: 'Validation failed',
            code: 'VALIDATION_ERROR',
          },
        ],
      };

      mockPowerSyncOperationService.processOperations.mockResolvedValue(
        response,
      );

      // Act
      await powerSyncController.processWriteOperations(request, user);

      // Assert
      expect(logSpy).toHaveBeenCalledWith(
        'Completed write operations for user partial-user: partial failure',
      );
    });

    it('should return error response for service failures', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const request: WriteBatchRequest = {
        operations: [
          new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
        ],
      };
      const serviceError = new Error('Database connection failed');

      mockPowerSyncOperationService.processOperations.mockRejectedValue(
        serviceError,
      );

      // Act
      const result = await powerSyncController.processWriteOperations(
        request,
        user,
      );

      // Assert
      expect(result).toEqual({
        success: false,
        errors: [
          {
            operation_id: -1,
            message: 'Internal server error processing write operations',
            code: 'INTERNAL_ERROR',
          },
        ],
      });
    });

    it('should preserve BadRequestException from service', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const request: WriteBatchRequest = {
        operations: [
          new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
        ],
      };
      const badRequestError = new BadRequestException(
        'Invalid operation format',
      );

      mockPowerSyncOperationService.processOperations.mockRejectedValue(
        badRequestError,
      );

      // Act & Assert
      await expect(
        powerSyncController.processWriteOperations(request, user),
      ).rejects.toThrow(BadRequestException);
      await expect(
        powerSyncController.processWriteOperations(request, user),
      ).rejects.toThrow('Invalid operation format');
    });

    it('should preserve UnauthorizedException from service', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const request: WriteBatchRequest = {
        operations: [
          new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
        ],
      };
      const unauthorizedError = new UnauthorizedException(
        'Insufficient permissions',
      );

      mockPowerSyncOperationService.processOperations.mockRejectedValue(
        unauthorizedError,
      );

      // Act & Assert
      await expect(
        powerSyncController.processWriteOperations(request, user),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('should log errors when operation processing fails', async () => {
      // Arrange
      const errorSpy = vi
        .spyOn(Logger.prototype, 'error')
        .mockImplementation(() => {});
      const user = DatabaseFixtures.createUserResult();
      const request: WriteBatchRequest = {
        operations: [
          new CrudEntry(1, UpdateType.PUT, 'test', '1', undefined, {}),
        ],
      };
      const serviceError = new Error('Operation validation failed');

      mockPowerSyncOperationService.processOperations.mockRejectedValue(
        serviceError,
      );

      // Act
      await powerSyncController.processWriteOperations(request, user);

      // Assert
      expect(errorSpy).toHaveBeenCalledWith(
        serviceError,
        'Failed to process write operations',
      );
    });

    it('should handle empty operations array', async () => {
      // Arrange
      const user = DatabaseFixtures.createUserResult();
      const request: WriteBatchRequest = { operations: [] };
      const response: WriteBatchResponse = { success: true };

      mockPowerSyncOperationService.processOperations.mockResolvedValue(
        response,
      );

      // Act
      const result = await powerSyncController.processWriteOperations(
        request,
        user,
      );

      // Assert
      expect(result).toEqual(response);
      expect(
        mockPowerSyncOperationService.processOperations,
      ).toHaveBeenCalledWith([], user);
    });
  });
});
