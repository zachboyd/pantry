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
        url: this.configService.get<string>('API_URL', 'http://localhost:3001'),
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
        pretty: this.configService.get<string>('LOG_PRETTY', 'true') === 'true',
      },
      database: {
        url: this.configService.get<string>('DATABASE_URL') || '',
      },
      redis: {
        url:
          this.configService.get<string>('REDIS_URL') ||
          'redis://localhost:6379',
      },
      openai: {
        apiKey: this.configService.get<string>('OPENAI_API_KEY'),
      },
      betterAuth: {
        secret: this.configService.get<string>('BETTER_AUTH_SECRET')!,
        google: {
          clientId: this.configService.get<string>('GOOGLE_CLIENT_ID')!,
          clientSecret: this.configService.get<string>('GOOGLE_CLIENT_SECRET')!,
        },
      },
      aws: {
        accessKeyId: this.configService.get<string>('AWS_ACCESS_KEY_ID'),
        secretAccessKey: this.configService.get<string>(
          'AWS_SECRET_ACCESS_KEY',
        ),
        region:
          this.configService.get<string>('AWS_S3_REGION') ||
          this.configService.get<string>('AWS_REGION') ||
          '',
        s3: {
          bucketName:
            this.configService.get<string>('AWS_S3_BUCKET_NAME') || '',
        },
        ses: {
          useMockService:
            this.configService.get<string>('USE_MOCK_EMAIL_SERVICE') === 'true',
          region:
            this.configService.get<string>('AWS_SES_REGION') ||
            this.configService.get<string>('AWS_REGION') ||
            'us-east-1',
          fromAddress:
            this.configService.get<string>('SES_FROM_ADDRESS') ||
            'noreply@jeevesapp.dev',
          configurationSetName: this.configService.get<string>(
            'SES_CONFIGURATION_SET_NAME',
          ),
        },
      },
    };
  }
}
