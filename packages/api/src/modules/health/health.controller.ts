import { Controller, Get, Inject } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Public } from '../auth/auth.decorator.js';
import { TOKENS } from '../../common/tokens.js';
import type { HealthService, HealthResponse } from './health.types.js';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    @Inject(TOKENS.HEALTH.SERVICE)
    private readonly healthService: HealthService,
  ) {}

  @Get()
  @Public()
  @ApiOperation({ summary: 'Get API health status' })
  @ApiResponse({
    status: 200,
    description: 'API health information',
  })
  getHealth(): HealthResponse {
    return this.healthService.getHealth();
  }
}
