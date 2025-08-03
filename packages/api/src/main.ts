import { NestFactory } from '@nestjs/core';
import {
  ExpressAdapter,
  NestExpressApplication,
} from '@nestjs/platform-express';
import { toNodeHandler } from 'better-auth/node';
import express from 'express';
import { Logger } from 'nestjs-pino';
import { AppModule } from './app.module.js';
import { requestContextMiddleware } from './common/middleware/request-context.middleware.js';
import { TOKENS } from './common/tokens.js';
import type { AuthFactory } from './modules/auth/auth.factory.js';
import type { ConfigService } from './modules/config/config.types.js';
import { SwaggerService } from './modules/swagger/swagger.service.js';

async function bootstrap() {
  // Create Express instance first
  const server = express();

  // Create NestJS app with Express adapter and disabled body parser
  const app = await NestFactory.create<NestExpressApplication>(
    AppModule,
    new ExpressAdapter(server),
    {
      bufferLogs: true,
      bodyParser: false,
    },
  );

  // Get configuration
  const configService = app.get<ConfigService>(TOKENS.CONFIG.SERVICE);
  const config = configService.config;

  // Get AuthFactory to create auth instance with sync callback
  const authFactory = app.get<AuthFactory>(TOKENS.AUTH.FACTORY);

  // Use Pino logger
  app.useLogger(app.get(Logger));
  const logger = app.get(Logger);

  // Enable shutdown hooks for proper cleanup
  app.enableShutdownHooks();

  app.enableCors({
    origin: config.app.corsOrigins,
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    credentials: true,
  });

  // Mount better-auth handler on Express server with sync callback
  server.all('/api/auth/*', toNodeHandler(authFactory.createAuthInstance()));
  server.use(express.json());

  // Apply request context middleware to NestJS app
  app.use(requestContextMiddleware);

  // Setup Swagger documentation using the service
  const swaggerService = app.get(SwaggerService);
  swaggerService.setupSwagger(app);

  // Start server
  await app.listen(config.app.port);

  logger.log(`🚀 API server running on port ${config.app.port}`);
  logger.log(`📝 Environment: ${config.app.nodeEnv}`);
  logger.log(`🔧 Log level: ${config.logging.level}`);
  logger.log(`📋 OpenAPI docs: http://localhost:${config.app.port}/api/docs`);
  logger.log(`📄 OpenAPI spec generated in src/generated/`);
}

bootstrap().catch((error) => {
  console.error('Failed to start application:', error);
  process.exit(1);
});
