import { Injectable, Logger } from '@nestjs/common';
import { Migrator, Kysely, PostgresDialect } from 'kysely';
import { Pool } from 'pg';
import * as path from 'path';
import type { DB } from '../../generated/database.js';
import type { DatabaseService } from '../../modules/database/database.types.js';
import { TestMigrationProvider } from './test-migration-provider.js';
import { DockerTestManager } from './docker-test-manager.js';

@Injectable()
export class TestDatabaseService implements DatabaseService {
  private readonly logger = new Logger(TestDatabaseService.name);
  private db: Kysely<DB> | null = null;

  getConnection(): Kysely<DB> {
    if (!this.db) {
      // Use Docker test database URL if available, otherwise fall back to env
      const databaseUrl =
        process.env.NODE_ENV === 'test'
          ? DockerTestManager.getTestDatabaseUrl()
          : process.env.DATABASE_URL;

      const dialect = new PostgresDialect({
        pool: new Pool({
          connectionString: databaseUrl,
          // Optimize for test performance
          max: 10,
          idleTimeoutMillis: 30000,
          connectionTimeoutMillis: 2000,
        }),
      });

      this.db = new Kysely<DB>({
        dialect,
      });

      this.logger.log(
        `📊 Test database connection established: ${databaseUrl?.split('@')[1] || 'unknown'}`,
      );
    }

    return this.db;
  }

  async runTestMigrations(): Promise<void> {
    try {
      const migrator = new Migrator({
        db: this.getConnection(),
        provider: new TestMigrationProvider(
          path.join(process.cwd(), 'src/database/migrations'),
        ),
      });

      const { error, results } = await migrator.migrateToLatest();

      if (results) {
        results.forEach((result) => {
          if (result.status === 'Success') {
            this.logger.log(
              `✅ Migration "${result.migrationName}" executed successfully`,
            );
          } else {
            this.logger.error(`❌ Migration "${result.migrationName}" failed`);
          }
        });
      }

      if (error) {
        this.logger.error(error, '❌ Migration failed');
        throw error;
      }

      this.logger.log('🎯 Test migrations completed successfully');
    } catch (error) {
      this.logger.error(error, '❌ Test migration setup failed:');
      throw error;
    }
  }

  async close(): Promise<void> {
    if (this.db) {
      await this.db.destroy();
      this.db = null;
      this.logger.log('🔌 Test database connection closed');
    }
  }
}
