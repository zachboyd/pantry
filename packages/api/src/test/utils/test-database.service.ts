import {
  Injectable,
  Logger,
} from '@nestjs/common';
import {
  Migrator,
  Kysely,
  PostgresDialect,
} from 'kysely';
import { Pool } from 'pg';
import * as path from 'path';
import type { DB } from '../../generated/database.js';
import type { DatabaseService } from '../../modules/database/database.types.js';
import { TestMigrationProvider } from './test-migration-provider.js';

@Injectable()
export class TestDatabaseService implements DatabaseService {
  private readonly logger = new Logger(TestDatabaseService.name);
  private db: Kysely<DB> | null = null;

  getConnection(): Kysely<DB> {
    if (!this.db) {
      const dialect = new PostgresDialect({
        pool: new Pool({
          connectionString: process.env.DATABASE_URL,
        }),
      });

      this.db = new Kysely<DB>({
        dialect,
      });

      this.logger.log('📊 Test database connection established');
    }

    return this.db;
  }

  async runTestMigrations(): Promise<void> {
    try {
      const migrator = new Migrator({
        db: this.getConnection(),
        provider: new TestMigrationProvider(
          path.join(process.cwd(), 'src/database/migrations')
        ),
      });

      const { error, results } = await migrator.migrateToLatest();

      if (results) {
        results.forEach((result) => {
          if (result.status === 'Success') {
            this.logger.log(`✅ Migration "${result.migrationName}" executed successfully`);
          } else {
            this.logger.error(`❌ Migration "${result.migrationName}" failed`);
          }
        });
      }

      if (error) {
        this.logger.error('❌ Migration failed', error);
        throw error;
      }

      this.logger.log('🎯 Test migrations completed successfully');
    } catch (error) {
      this.logger.error('❌ Test migration setup failed:', error);
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