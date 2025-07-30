import { Module } from '@nestjs/common';
import { HealthController } from './health.controller.js';
import { HealthServiceImpl } from './health.service.js';
import { TOKENS } from '../../common/tokens.js';

@Module({
  controllers: [HealthController],
  providers: [
    {
      provide: TOKENS.HEALTH.SERVICE,
      useClass: HealthServiceImpl,
    },
  ],
  exports: [TOKENS.HEALTH.SERVICE],
})
export class HealthModule {}
