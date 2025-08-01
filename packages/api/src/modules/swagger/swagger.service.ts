import { INestApplication, Inject, Injectable } from '@nestjs/common';
import { DocumentBuilder, OpenAPIObject, SwaggerModule } from '@nestjs/swagger';
import { mkdirSync, writeFileSync } from 'fs';
import yaml from 'js-yaml';
import { join } from 'path';
import { TOKENS } from '../../common/tokens.js';
import type { ConfigService } from '../config/config.types.js';

@Injectable()
export class SwaggerService {
  constructor(
    @Inject(TOKENS.CONFIG.SERVICE)
    private readonly configService: ConfigService,
  ) {}

  setupSwagger(app: INestApplication): void {
    const config = this.configService.config;

    // Build OpenAPI configuration dynamically
    const swaggerConfig = new DocumentBuilder()
      .setTitle('Pantry API')
      .setDescription('API for collaborative pantry planning')
      .setVersion('1.0.0');

    // Add servers based on environment
    if (config.app.nodeEnv === 'production') {
      swaggerConfig.addServer('https://api.pantry.com/v1', 'Production server');
    } else if (config.app.nodeEnv === 'staging') {
      swaggerConfig.addServer(
        'https://api-staging.pantry.com/v1',
        'Staging server',
      );
    }

    // Always add local development server
    swaggerConfig.addServer(
      `http://localhost:${config.app.port}`,
      'Local development server',
    );

    // Add authentication schemes
    swaggerConfig.addCookieAuth('session', {
      type: 'apiKey',
      in: 'cookie',
      name: 'pantry.session_token',
      description: 'Session cookie from Better Auth',
    });

    // Add tags for implemented modules only
    swaggerConfig
      .addTag('health', 'API health and status monitoring')
      .addTag('auth', 'Authentication and user management');

    const document = SwaggerModule.createDocument(app, swaggerConfig.build());

    // Add Better Auth endpoints manually
    this.addBetterAuthEndpoints(document);

    // Setup Swagger UI
    SwaggerModule.setup('api/docs', app, document, {
      customSiteTitle: 'Pantry API Documentation',
      swaggerOptions: {
        persistAuthorization: true,
        displayRequestDuration: true,
      },
    });

    // Generate OpenAPI files
    this.generateOpenApiFiles(document);
  }

  private addBetterAuthEndpoints(document: OpenAPIObject): void {
    // Ensure paths object exists
    if (!document.paths) {
      document.paths = {};
    }

    // Better Auth Sign In
    document.paths['/api/auth/sign-in/email'] = {
      post: {
        tags: ['auth'],
        summary: 'Sign in with email and password',
        description: 'Authenticate user with email and password credentials',
        operationId: 'signInEmail',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                  email: {
                    type: 'string',
                    format: 'email',
                    description: 'User email address',
                  },
                  password: {
                    type: 'string',
                    minLength: 6,
                    description: 'User password',
                  },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Successfully authenticated',
            headers: {
              'Set-Cookie': {
                description: 'Session cookie',
                schema: {
                  type: 'string',
                },
              },
            },
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    user: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        email: { type: 'string' },
                        name: { type: 'string' },
                        emailVerified: { type: 'boolean' },
                        image: { type: 'string', nullable: true },
                        createdAt: { type: 'string', format: 'date-time' },
                        updatedAt: { type: 'string', format: 'date-time' },
                      },
                    },
                    session: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        userId: { type: 'string' },
                        expiresAt: { type: 'string', format: 'date-time' },
                      },
                    },
                  },
                },
              },
            },
          },
          '400': {
            description: 'Invalid credentials or request format',
          },
          '401': {
            description: 'Authentication failed',
          },
        },
      },
    };

    // Better Auth Sign Up
    document.paths['/api/auth/sign-up/email'] = {
      post: {
        tags: ['auth'],
        summary: 'Sign up with email and password',
        description: 'Create a new user account with email and password',
        operationId: 'signUpEmail',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email', 'password', 'name'],
                properties: {
                  email: {
                    type: 'string',
                    format: 'email',
                    description: 'User email address',
                  },
                  password: {
                    type: 'string',
                    minLength: 6,
                    description: 'User password',
                  },
                  name: {
                    type: 'string',
                    minLength: 1,
                    description: 'User full name',
                  },
                },
              },
            },
          },
        },
        responses: {
          '201': {
            description: 'User created successfully',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    user: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        email: { type: 'string' },
                        name: { type: 'string' },
                        emailVerified: { type: 'boolean' },
                        createdAt: { type: 'string', format: 'date-time' },
                      },
                    },
                  },
                },
              },
            },
          },
          '400': {
            description: 'Invalid request format or user already exists',
          },
        },
      },
    };

    // Better Auth Get Session
    document.paths['/api/auth/session'] = {
      get: {
        tags: ['auth'],
        summary: 'Get current session',
        description: 'Retrieve current user session information',
        operationId: 'getSession',
        security: [{ session: [] }],
        responses: {
          '200': {
            description: 'Current session information',
            content: {
              'application/json': {
                schema: {
                  type: 'object',
                  properties: {
                    user: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        email: { type: 'string' },
                        name: { type: 'string' },
                        emailVerified: { type: 'boolean' },
                        image: { type: 'string', nullable: true },
                      },
                    },
                    session: {
                      type: 'object',
                      properties: {
                        id: { type: 'string' },
                        userId: { type: 'string' },
                        expiresAt: { type: 'string', format: 'date-time' },
                      },
                    },
                  },
                },
              },
            },
          },
          '401': {
            description: 'No active session',
          },
        },
      },
    };

    // Better Auth Sign Out
    document.paths['/api/auth/sign-out'] = {
      post: {
        tags: ['auth'],
        summary: 'Sign out',
        description: 'End current user session',
        operationId: 'signOut',
        security: [{ session: [] }],
        responses: {
          '200': {
            description: 'Successfully signed out',
            headers: {
              'Set-Cookie': {
                description: 'Clear session cookie',
                schema: {
                  type: 'string',
                },
              },
            },
          },
        },
      },
    };

    // Better Auth Forgot Password
    document.paths['/api/auth/forgot-password'] = {
      post: {
        tags: ['auth'],
        summary: 'Request password reset',
        description: 'Send password reset email to user',
        operationId: 'forgotPassword',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['email'],
                properties: {
                  email: {
                    type: 'string',
                    format: 'email',
                    description: 'User email address',
                  },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Password reset email sent (if email exists)',
          },
          '400': {
            description: 'Invalid email format',
          },
        },
      },
    };

    // Better Auth Reset Password
    document.paths['/api/auth/reset-password'] = {
      post: {
        tags: ['auth'],
        summary: 'Reset password',
        description: 'Reset user password with reset token',
        operationId: 'resetPassword',
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                type: 'object',
                required: ['token', 'password'],
                properties: {
                  token: {
                    type: 'string',
                    description: 'Password reset token from email',
                  },
                  password: {
                    type: 'string',
                    minLength: 6,
                    description: 'New password',
                  },
                },
              },
            },
          },
        },
        responses: {
          '200': {
            description: 'Password reset successfully',
          },
          '400': {
            description: 'Invalid or expired token',
          },
        },
      },
    };
  }

  private generateOpenApiFiles(document: OpenAPIObject): void {
    const generatedDir = join(process.cwd(), 'src', 'generated');
    mkdirSync(generatedDir, { recursive: true });

    // Write YAML version only
    const yamlContent = yaml.dump(document, { indent: 2, lineWidth: 120 });
    writeFileSync(join(generatedDir, 'openapi.yaml'), yamlContent);
  }
}
