import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { LoggerModule as PinoLoggerModule } from 'nestjs-pino';
import { RequestContextService } from '../../common/context/request-context.service.js';
import { AppConfigModule } from '../config/config.module.js';

@Module({
  imports: [
    AppConfigModule, // Explicit dependency to ensure ConfigService is available
    PinoLoggerModule.forRootAsync({
      useFactory: (configService: ConfigService) => {
        // Get config values directly from NestJS ConfigService, matching our config structure
        const nodeEnv = configService.get<string>('NODE_ENV', 'development');
        const logLevel = configService.get<string>(
          'LOG_LEVEL',
          nodeEnv === 'production' ? 'info' : 'debug',
        );

        // Support LOG_PRETTY environment variable override, otherwise default based on NODE_ENV
        const logPrettyEnv = configService.get<string>('LOG_PRETTY');
        const isPretty = logPrettyEnv
          ? logPrettyEnv.toLowerCase() === 'true'
          : nodeEnv === 'development';

        return {
          pinoHttp: {
            level: logLevel,

            // Development vs Production formatting
            transport: isPretty
              ? {
                  target: 'pino-pretty',
                  options: {
                    colorize: true,
                    levelFirst: true,
                    translateTime: 'yyyy-mm-dd HH:MM:ss',
                    ignore: 'pid,hostname,req,res',
                    singleLine: false,
                  },
                }
              : undefined,

            // Disable HTTP request auto-logging to reduce verbosity
            autoLogging: false,

            // Completely disable request/response serialization
            serializers: {
              req: () => undefined,
              res: () => undefined,
            },

            // Custom request context
            customProps: () => ({
              correlationId: RequestContextService.getCorrelationId(),
            }),

            // Redact sensitive information
            redact: {
              paths: [
                'req.headers.authorization',
                'req.headers.cookie',
                'req.body.password',
                'req.body.token',
              ],
              censor: '[REDACTED]',
            },
          },
        };
      },
      inject: [ConfigService], // Inject NestJS ConfigService directly
    }),
  ],
})
export class AppLoggerModule {}
