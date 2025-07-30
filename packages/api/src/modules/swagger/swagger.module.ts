import { Module } from '@nestjs/common';
import { AppConfigModule } from '../config/config.module.js';
import { SwaggerService } from './swagger.service.js';

@Module({
  imports: [AppConfigModule],
  providers: [SwaggerService],
  exports: [SwaggerService],
})
export class SwaggerModule {}
