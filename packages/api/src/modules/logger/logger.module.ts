import { Module } from '@nestjs/common';
import { LoggerModule as PinoLoggerModule } from 'nestjs-pino';
import { RequestContextService } from '../../common/context/request-context.service.js';
import { AppConfigModule } from '../config/config.module.js';
import { TOKENS } from '../../common/tokens.js';
import type { ConfigService } from '../config/config.types.js';

@Module({
  imports: [
    AppConfigModule, // Explicit dependency to ensure ConfigService is available
    PinoLoggerModule.forRootAsync({
      useFactory: (configService: ConfigService) => {
        // Use our centralized config service
        const config = configService.config;
        const logLevel = config.logging.level;
        const isPretty = config.logging.pretty;

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
      inject: [TOKENS.CONFIG.SERVICE], // Inject our ConfigService
    }),
  ],
})
export class AppLoggerModule {}
