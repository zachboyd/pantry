import { describe, it, expect, beforeEach, vi } from 'vitest';
import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { PermissionEventHandler } from '../permission.event-handler.js';
import { TOKENS } from '../../../common/tokens.js';
import { RecomputeUserPermissionsEvent } from '../events/permission-events.js';
import { PermissionServiceMock } from '../../../test/mocks/permission-service.mock.js';
import type { PermissionServiceMockType } from '../../../test/mocks/permission-service.mock.js';

describe('PermissionEventHandler', () => {
  let handler: PermissionEventHandler;
  let mockPermissionService: PermissionServiceMockType;

  beforeEach(async () => {
    // Create reusable mock
    mockPermissionService = PermissionServiceMock.createPermissionServiceMock();

    // Mock logger to avoid console output during tests
    vi.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PermissionEventHandler,
        {
          provide: TOKENS.PERMISSION.SERVICE,
          useValue: mockPermissionService,
        },
      ],
    }).compile();

    handler = module.get<PermissionEventHandler>(PermissionEventHandler);
  });

  describe('handleRecomputeUserPermissions', () => {
    it('should invalidate and recompute user permissions successfully', async () => {
      const userId = 'test-user-id';
      const event = new RecomputeUserPermissionsEvent(userId);

      await handler.handleRecomputeUserPermissions(event);

      expect(
        mockPermissionService.invalidateUserPermissions,
      ).toHaveBeenCalledWith(userId);
      expect(mockPermissionService.computeUserPermissions).toHaveBeenCalledWith(
        userId,
      );
      expect(Logger.prototype.log).toHaveBeenCalledWith(
        `Recomputed permissions for user ${userId}`,
      );
    });

    it('should include reason in log message when provided', async () => {
      const userId = 'test-user-id';
      const reason = 'household role changed';
      const event = new RecomputeUserPermissionsEvent(userId, reason);

      await handler.handleRecomputeUserPermissions(event);

      expect(
        mockPermissionService.invalidateUserPermissions,
      ).toHaveBeenCalledWith(userId);
      expect(mockPermissionService.computeUserPermissions).toHaveBeenCalledWith(
        userId,
      );
      expect(Logger.prototype.log).toHaveBeenCalledWith(
        `Recomputed permissions for user ${userId} (${reason})`,
      );
    });

    it('should call invalidateUserPermissions before computeUserPermissions', async () => {
      const userId = 'test-user-id';
      const event = new RecomputeUserPermissionsEvent(userId);
      const callOrder: string[] = [];

      mockPermissionService.invalidateUserPermissions = vi
        .fn()
        .mockImplementation(() => {
          callOrder.push('invalidate');
          return Promise.resolve();
        });

      mockPermissionService.computeUserPermissions = vi
        .fn()
        .mockImplementation(() => {
          callOrder.push('compute');
          return Promise.resolve();
        });

      await handler.handleRecomputeUserPermissions(event);

      expect(callOrder).toEqual(['invalidate', 'compute']);
    });

    it('should handle errors during invalidation and log them', async () => {
      const userId = 'test-user-id';
      const event = new RecomputeUserPermissionsEvent(userId);
      const error = new Error('Cache invalidation failed');

      mockPermissionService.invalidateUserPermissions = vi
        .fn()
        .mockRejectedValue(error);

      await handler.handleRecomputeUserPermissions(event);

      expect(
        mockPermissionService.invalidateUserPermissions,
      ).toHaveBeenCalledWith(userId);
      expect(
        mockPermissionService.computeUserPermissions,
      ).not.toHaveBeenCalled();
      expect(Logger.prototype.error).toHaveBeenCalledWith(
        `Failed to recompute permissions for user ${userId}:`,
        error,
      );
    });

    it('should handle errors during computation and log them', async () => {
      const userId = 'test-user-id';
      const event = new RecomputeUserPermissionsEvent(userId);
      const error = new Error('Permission computation failed');

      mockPermissionService.computeUserPermissions = vi
        .fn()
        .mockRejectedValue(error);

      await handler.handleRecomputeUserPermissions(event);

      expect(
        mockPermissionService.invalidateUserPermissions,
      ).toHaveBeenCalledWith(userId);
      expect(mockPermissionService.computeUserPermissions).toHaveBeenCalledWith(
        userId,
      );
      expect(Logger.prototype.error).toHaveBeenCalledWith(
        `Failed to recompute permissions for user ${userId}:`,
        error,
      );
    });

    it('should handle errors with reason in event and include it in error log', async () => {
      const userId = 'test-user-id';
      const reason = 'household member removed';
      const event = new RecomputeUserPermissionsEvent(userId, reason);
      const error = new Error('Database connection failed');

      mockPermissionService.invalidateUserPermissions = vi
        .fn()
        .mockRejectedValue(error);

      await handler.handleRecomputeUserPermissions(event);

      expect(Logger.prototype.error).toHaveBeenCalledWith(
        `Failed to recompute permissions for user ${userId}:`,
        error,
      );
    });

    it('should not throw errors even when service methods fail', async () => {
      const userId = 'test-user-id';
      const event = new RecomputeUserPermissionsEvent(userId);

      mockPermissionService.invalidateUserPermissions = vi
        .fn()
        .mockRejectedValue(new Error('Service error'));
      mockPermissionService.computeUserPermissions = vi
        .fn()
        .mockRejectedValue(new Error('Another error'));

      // Should not throw
      await expect(
        handler.handleRecomputeUserPermissions(event),
      ).resolves.not.toThrow();
    });
  });
});
