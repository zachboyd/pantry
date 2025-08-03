import { DockerTestManager } from '../utils/docker-test-manager.js';

/**
 * Global setup for all integration tests
 * Runs once before all test suites start
 * Spins up Docker database and Redis containers
 */
export default async function globalSetup() {
  console.log('🌍 Global test setup starting...');

  try {
    // Check if Docker is available
    DockerTestManager.checkDockerAvailable();

    // Start Docker services for tests
    await DockerTestManager.startServices();

    console.log('✅ Global test setup complete');

    // Return teardown function
    return async () => {
      console.log('🌍 Global test teardown starting...');

      try {
        // Stop Docker services
        await DockerTestManager.stopServices();

        console.log('✅ Global test teardown complete');
      } catch (error) {
        console.error('❌ Global test teardown failed:', error);
        // Don't throw here - teardown should be best effort
      }
    };
  } catch (error) {
    console.error('❌ Global test setup failed:', error);
    // Try to cleanup on failure
    await DockerTestManager.stopServices();
    throw error;
  }
}
