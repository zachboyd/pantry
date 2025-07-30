import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Inject,
  Logger,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { TOKENS } from '../../common/tokens.js';
import { Public, User } from '../auth/auth.decorator.js';
import type { UserRecord } from '../user/user.types.js';
import type {
  PowerSyncAuthResponse,
  PowerSyncAuthService,
  PowerSyncOperationService,
  WriteBatchRequest,
  WriteBatchResponse,
} from './powersync.types.js';

@ApiTags('powersync')
@Controller('api/powersync')
export class PowerSyncController {
  private readonly logger = new Logger(PowerSyncController.name);

  constructor(
    @Inject(TOKENS.POWERSYNC.AUTH_SERVICE)
    private readonly powerSyncAuthService: PowerSyncAuthService,
    @Inject(TOKENS.POWERSYNC.OPERATION_SERVICE)
    private readonly powerSyncOperationService: PowerSyncOperationService,
  ) {}

  @Post('auth')
  @ApiOperation({ summary: 'Authenticate user for PowerSync' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'PowerSync authentication token',
    schema: {
      type: 'object',
      properties: {
        token: { type: 'string' },
        expires_at: { type: 'number' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  async authenticateForPowerSync(
    @User() user: UserRecord | null,
  ): Promise<PowerSyncAuthResponse> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      // Generate PowerSync JWT
      const powerSyncToken =
        await this.powerSyncAuthService.generateToken(user);

      // Calculate expiration using service's configured duration
      const expirationSeconds = this.powerSyncAuthService.getExpirationSeconds();
      const expiresAt = Math.floor(Date.now() / 1000) + expirationSeconds;

      this.logger.log(`Generated PowerSync token for user ${user.id}`);

      return {
        token: powerSyncToken,
        expires_at: expiresAt,
      };
    } catch (error) {
      this.logger.error(error, 'PowerSync authentication failed');
      if (
        error instanceof BadRequestException ||
        error instanceof UnauthorizedException
      ) {
        throw error;
      }
      throw new UnauthorizedException('Authentication failed');
    }
  }

  @Public()
  @Get('jwks')
  @ApiOperation({ summary: 'Get JSON Web Key Set for PowerSync' })
  @ApiResponse({
    status: 200,
    description: 'JWKS endpoint for PowerSync token verification',
    schema: {
      type: 'object',
      properties: {
        keys: {
          type: 'array',
          items: { type: 'object' },
        },
      },
    },
  })
  async getJwks() {
    try {
      const jwks = await this.powerSyncAuthService.getJwks();
      this.logger.debug('Served JWKS endpoint');
      return jwks;
    } catch (error) {
      this.logger.error(error, 'Failed to serve JWKS');
      throw error;
    }
  }

  @Post('write')
  @ApiOperation({ summary: 'Process PowerSync write operations' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Write operations processed',
    schema: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        errors: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              operation_id: { type: 'number' },
              message: { type: 'string' },
              code: { type: 'string' },
            },
          },
        },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({
    status: 400,
    description: 'Bad Request - Invalid operations array',
  })
  async processWriteOperations(
    @Body() request: WriteBatchRequest,
    @User() user: UserRecord | null,
  ): Promise<WriteBatchResponse> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      if (!request.operations || !Array.isArray(request.operations)) {
        throw new BadRequestException(
          'Invalid request: operations array required',
        );
      }

      this.logger.log(
        `Processing ${request.operations.length} write operations for user ${user.id}`,
      );

      const result = await this.powerSyncOperationService.processOperations(
        request.operations,
        user,
      );

      this.logger.log(
        `Completed write operations for user ${user.id}: ${result.success ? 'success' : 'partial failure'}`,
      );

      return result;
    } catch (error) {
      this.logger.error(error, 'Failed to process write operations');
      if (
        error instanceof BadRequestException ||
        error instanceof UnauthorizedException
      ) {
        throw error;
      }
      // Return 200 with error details as per PowerSync documentation
      return {
        success: false,
        errors: [
          {
            operation_id: -1,
            message: 'Internal server error processing write operations',
            code: 'INTERNAL_ERROR',
          },
        ],
      };
    }
  }
}
