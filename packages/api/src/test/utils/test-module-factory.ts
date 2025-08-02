import { Test, TestingModule } from '@nestjs/testing';
import { ModuleMetadata, Provider } from '@nestjs/common';

/**
 * Factory for creating NestJS test modules with consistent configuration
 */
export class TestModuleFactory {
  /**
   * Creates a basic test module with the provided metadata
   */
  static async create(metadata: ModuleMetadata): Promise<TestingModule> {
    return Test.createTestingModule(metadata).compile();
  }

  /**
   * Creates a test module with service mocking helper
   * Useful for unit testing services with mocked dependencies
   */
  static async createWithMocks<T = unknown>(
    serviceClass: new (...args: unknown[]) => T,
    mocks: Record<string, unknown> = {},
    additionalProviders: Provider[] = [],
  ): Promise<{ module: TestingModule; service: T }> {
    const providers: Provider[] = [serviceClass, ...additionalProviders];

    // Add mocked providers
    Object.entries(mocks).forEach(([token, mockValue]) => {
      providers.push({
        provide: token,
        useValue: mockValue,
      });
    });

    const module = await Test.createTestingModule({
      providers,
    }).compile();

    const service = module.get<T>(serviceClass);

    return { module, service };
  }

  /**
   * Creates a test module for controller testing with mocked services
   */
  static async createControllerModule<T = unknown>(
    controllerClass: new (...args: unknown[]) => T,
    serviceMocks: Record<string, unknown> = {},
  ): Promise<{ module: TestingModule; controller: T }> {
    const providers = Object.entries(serviceMocks).map(
      ([token, mockValue]) => ({
        provide: token,
        useValue: mockValue,
      }),
    );

    const module = await Test.createTestingModule({
      controllers: [controllerClass],
      providers,
    }).compile();

    const controller = module.get<T>(controllerClass);

    return { module, controller };
  }
}
