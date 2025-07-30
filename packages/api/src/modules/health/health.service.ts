import { Injectable } from '@nestjs/common';
import type { HealthResponse, HealthService } from './health.types.js';

@Injectable()
export class HealthServiceImpl implements HealthService {
  getHealth(): HealthResponse {
    const response: HealthResponse = {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };

    return response;
  }
}
