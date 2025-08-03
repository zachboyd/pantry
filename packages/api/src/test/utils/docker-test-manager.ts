import { spawn, execSync } from 'child_process';
import { promisify } from 'util';
import { Logger } from '@nestjs/common';
import * as path from 'path';

/**
 * Manages Docker Compose services for integration testing
 * Spins up fresh database and Redis containers before tests
 * Tears them down after tests complete
 */
export class DockerTestManager {
  private static readonly logger = new Logger(DockerTestManager.name);
  private static readonly COMPOSE_FILE = 'docker-compose.test.yml';
  private static readonly SERVICE_READY_TIMEOUT = 30000; // 30 seconds
  private static readonly HEALTH_CHECK_INTERVAL = 1000; // 1 second
  
  private static isSetup = false;
  private static readonly projectRoot = path.resolve(process.cwd());

  /**
   * Start Docker Compose services for testing
   * This should be called once before all integration tests
   */
  static async startServices(): Promise<void> {
    if (this.isSetup) {
      this.logger.log('🐳 Docker test services already running');
      return;
    }

    try {
      this.logger.log('🚀 Starting Docker test services...');
      
      // Stop any existing test services first
      await this.stopServices();
      
      // Start services with health checks
      const composeCommand = [
        'docker', 'compose',
        '-f', this.COMPOSE_FILE,
        '-p', 'pantry-test',  // Use project name to avoid conflicts
        'up', '-d', '--wait'
      ];

      execSync(composeCommand.join(' '), {
        stdio: 'pipe',
        cwd: this.projectRoot,
        timeout: this.SERVICE_READY_TIMEOUT,
      });

      // Wait for services to be healthy
      await this.waitForServicesHealthy();
      
      this.isSetup = true;
      this.logger.log('✅ Docker test services are ready');
      
      // Set environment variables for tests
      this.setTestEnvironmentVariables();
      
    } catch (error) {
      this.logger.error('❌ Failed to start Docker test services:', error);
      await this.stopServices(); // Cleanup on failure
      throw new Error(`Failed to start test database: ${error}`);
    }
  }

  /**
   * Stop Docker Compose services
   * This should be called once after all integration tests
   */
  static async stopServices(): Promise<void> {
    try {
      this.logger.log('🛑 Stopping Docker test services...');
      
      const composeCommand = [
        'docker', 'compose',
        '-f', this.COMPOSE_FILE,
        '-p', 'pantry-test',
        'down', '-v', '--remove-orphans'  // Remove volumes and orphaned containers
      ];

      execSync(composeCommand.join(' '), {
        stdio: 'pipe',
        cwd: this.projectRoot,
        timeout: 15000, // 15 seconds to stop
      });
      
      this.isSetup = false;
      this.logger.log('✅ Docker test services stopped');
      
    } catch (error) {
      this.logger.warn('⚠️ Error stopping Docker test services (may not be running):', error);
      // Don't throw here - cleanup should be best effort
    }
  }

  /**
   * Wait for all services to report healthy status
   */
  private static async waitForServicesHealthy(): Promise<void> {
    const maxWaitTime = this.SERVICE_READY_TIMEOUT;
    const startTime = Date.now();
    
    this.logger.log('⏳ Waiting for services to be healthy...');
    
    while (Date.now() - startTime < maxWaitTime) {
      try {
        // Check if all services are healthy
        const healthOutput = execSync(
          `docker compose -f ${this.COMPOSE_FILE} -p pantry-test ps --format json`,
          { 
            stdio: 'pipe', 
            cwd: this.projectRoot,
            encoding: 'utf8'
          }
        );

        const services = healthOutput.trim().split('\n')
          .filter(line => line.trim())
          .map(line => JSON.parse(line));
        
        const allHealthy = services.every(service => 
          service.Health === 'healthy' || service.State === 'running'
        );

        if (allHealthy && services.length > 0) {
          this.logger.log('💚 All services are healthy');
          return;
        }

        this.logger.log(`⏳ Services status: ${services.map(s => `${s.Service}:${s.Health || s.State}`).join(', ')}`);
        
      } catch (error) {
        this.logger.log('⏳ Checking service health...');
      }
      
      await new Promise(resolve => setTimeout(resolve, this.HEALTH_CHECK_INTERVAL));
    }
    
    throw new Error(`Services did not become healthy within ${maxWaitTime}ms`);
  }

  /**
   * Set environment variables for test database connections
   */
  private static setTestEnvironmentVariables(): void {
    process.env.DATABASE_URL = 'postgresql://pantry_test:pantry_test_pass@localhost:5433/pantry_test';
    process.env.REDIS_URL = 'redis://localhost:6380';
    
    this.logger.log('🔧 Test environment variables set');
  }

  /**
   * Get the test database connection string
   */
  static getTestDatabaseUrl(): string {
    return 'postgresql://pantry_test:pantry_test_pass@localhost:5433/pantry_test';
  }

  /**
   * Get the test Redis connection string
   */
  static getTestRedisUrl(): string {
    return 'redis://localhost:6380';
  }

  /**
   * Reset the database by dropping and recreating all tables
   * This is faster than spinning up a new container for each test suite
   */
  static async resetDatabase(): Promise<void> {
    try {
      this.logger.log('🔄 Resetting test database...');
      
      // Execute SQL to drop all tables and recreate schema
      const resetCommand = [
        'docker', 'exec',
        'pantry-test-pantry-test-postgres-1',  // Container name pattern
        'psql',
        '-U', 'pantry_test',
        '-d', 'pantry_test',
        '-c', 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
      ];

      execSync(resetCommand.join(' '), {
        stdio: 'pipe',
        timeout: 10000,
      });
      
      this.logger.log('✅ Test database reset complete');
      
    } catch (error) {
      this.logger.error('❌ Failed to reset test database:', error);
      throw error;
    }
  }

  /**
   * Check if Docker and Docker Compose are available
   */
  static checkDockerAvailable(): void {
    try {
      execSync('docker --version', { stdio: 'pipe' });
      execSync('docker compose version', { stdio: 'pipe' });
    } catch (error) {
      throw new Error(
        'Docker or Docker Compose not available. Please install Docker Desktop or Docker Engine with Docker Compose.'
      );
    }
  }
}