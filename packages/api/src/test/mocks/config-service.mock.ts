import type {
  ConfigService,
  Configuration,
} from '../../modules/config/config.types.js';

/**
 * ConfigService mock factory for consistent testing
 * Follows the same pattern as other service mocks in the codebase
 */
export class ConfigServiceMock {
  /**
   * Creates a mock ConfigService for testing
   * Returns a default test configuration
   */
  static createConfigServiceMock(
    configOverrides?: Partial<Configuration>,
  ): ConfigService {
    const defaultConfig: Configuration = {
      app: {
        port: 3000,
        nodeEnv: 'test',
        corsOrigins: ['http://localhost:3000'],
      },
      logging: {
        level: 'info',
        pretty: false,
      },
      database: {
        url: 'postgresql://test:test@localhost:5432/test_db',
      },
      redis: {
        url: 'redis://localhost:6379',
      },
      openai: {
        apiKey: 'test-openai-key',
      },
      aws: {
        accessKeyId: 'test-access-key',
        secretAccessKey: 'test-secret-key',
        region: 'us-east-1',
        s3: {
          bucketName: 'test-bucket',
        },
        ses: {
          region: 'us-east-1',
          fromAddress: 'noreply@test.com',
          configurationSetName: 'test-config-set',
        },
      },
    };

    const config = configOverrides
      ? { ...defaultConfig, ...configOverrides }
      : defaultConfig;

    return {
      config,
    };
  }

  /**
   * Creates a ConfigService mock for development environment
   */
  static createDevelopmentConfigServiceMock(): ConfigService {
    return this.createConfigServiceMock({
      app: {
        port: 3001,
        nodeEnv: 'development',
        corsOrigins: ['http://localhost:3000', 'http://localhost:5173'],
      },
      logging: {
        level: 'debug',
        pretty: true,
      },
    });
  }

  /**
   * Creates a ConfigService mock for production environment
   */
  static createProductionConfigServiceMock(): ConfigService {
    return this.createConfigServiceMock({
      app: {
        port: 80,
        nodeEnv: 'production',
        corsOrigins: ['https://app.jeevesapp.dev'],
      },
      logging: {
        level: 'info',
        pretty: false,
      },
      aws: {
        accessKeyId: 'prod-access-key',
        secretAccessKey: 'prod-secret-key',
        region: 'us-east-1',
        s3: {
          bucketName: 'jeeves-prod-bucket',
        },
        ses: {
          region: 'us-east-1',
          fromAddress: 'noreply@jeevesapp.dev',
          configurationSetName: 'jeeves-prod-config-set',
        },
      },
    });
  }

  /**
   * Creates a ConfigService mock with minimal configuration
   * Useful for testing error scenarios or missing config values
   */
  static createMinimalConfigServiceMock(): ConfigService {
    return this.createConfigServiceMock({
      aws: {
        accessKeyId: undefined,
        secretAccessKey: undefined,
        region: '',
        s3: {
          bucketName: '',
        },
        ses: {
          region: 'us-east-1',
          fromAddress: 'noreply@localhost.dev',
          configurationSetName: undefined,
        },
      },
    });
  }
}
