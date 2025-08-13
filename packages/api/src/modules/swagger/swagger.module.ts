import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import { SwaggerService } from './swagger.service.js';
import type { SwaggerConfig } from './swagger.types.js';
import type { ConfigService } from '../config/config.types.js';

@Module({
  imports: [AppConfigModule],
  providers: [
    {
      provide: TOKENS.SWAGGER.CONFIG,
      useFactory: (configService: ConfigService): SwaggerConfig => {
        return {
          app: {
            port: configService.config.app.port,
            nodeEnv: configService.config.app.nodeEnv,
          },
        };
      },
      inject: [TOKENS.CONFIG.SERVICE],
    },
    {
      provide: TOKENS.SWAGGER.SERVICE,
      useClass: SwaggerService,
    },
  ],
  exports: [TOKENS.SWAGGER.SERVICE],
})
export class SwaggerModule {}
