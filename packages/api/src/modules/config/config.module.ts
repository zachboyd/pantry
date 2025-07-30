import { Global, Module } from '@nestjs/common';
import {
  ConfigModule,
  ConfigService as NestConfigService,
} from '@nestjs/config';
import { TOKENS } from '../../common/tokens.js';
import { ConfigServiceImpl } from './config.service.js';

@Global()
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.local', '.env'],
      cache: true,
    }),
  ],
  providers: [
    {
      provide: TOKENS.CONFIG.SERVICE,
      useFactory: async (nestConfigService: NestConfigService) => {
        await ConfigModule.envVariablesLoaded;
        return new ConfigServiceImpl(nestConfigService);
      },
      inject: [NestConfigService],
    },
  ],
  exports: [TOKENS.CONFIG.SERVICE],
})
export class AppConfigModule {}
