import { Injectable } from '@nestjs/common';
import { ConfigService as NestConfigService } from '@nestjs/config';
import type { ConfigService, Configuration } from './config.types.js';

@Injectable()
export class ConfigServiceImpl implements ConfigService {
  constructor(private readonly configService: NestConfigService) {}

  get config(): Configuration {
    const nodeEnv = this.configService.get<string>('NODE_ENV', 'development');

    return {
      app: {
        port: this.configService.get<number>('PORT', 3001),
        nodeEnv,
        corsOrigins: this.configService
          .get<string>(
            'CORS_ORIGINS',
            'http://localhost:3000,http://localhost:5173',
          )
          .split(',')
          .map((origin) => origin.trim()),
      },
      logging: {
        level: this.configService.get<string>(
          'LOG_LEVEL',
          nodeEnv === 'production' ? 'info' : 'debug',
        ),
        pretty: nodeEnv === 'development',
      },
      database: {
        url: this.configService.get<string>('DATABASE_URL') || '',
      },
      openai: {
        apiKey: this.configService.get<string>('OPENAI_API_KEY'),
      },
    };
  }
}
