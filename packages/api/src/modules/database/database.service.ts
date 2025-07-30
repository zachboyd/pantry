import {
  Injectable,
  Logger,
  OnModuleInit,
  OnApplicationShutdown,
} from '@nestjs/common';
import { promises as fs } from 'fs';
import {
  FileMigrationProvider,
  Migrator,
  Kysely,
  PostgresDialect,
} from 'kysely';
import { Pool } from 'pg';
import * as path from 'path';
import type { DB } from '../../generated/database.js';
import type { DatabaseService } from './database.types.js';

@Injectable()
export class DatabaseServiceImpl
  implements DatabaseService, OnModuleInit, OnApplicationShutdown
{
  private readonly logger = new Logger(DatabaseServiceImpl.name);
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

      this.logger.log('📊 Database connection established');
    }

    return this.db;
  }

  async onModuleInit() {
    const autoMigrate = process.env.AUTO_MIGRATE !== 'false'; // Default to true

    if (autoMigrate) {
      this.logger.log(
        '🔄 Auto-migration enabled, running database migrations...',
      );
      await this.runMigrations();
    } else {
      this.logger.log('⏸️ Auto-migration disabled');
    }

    // Better Auth will be initialized lazily when first needed
    this.logger.log('🔐 Better Auth will be initialized on first use');
  }

  private async runMigrations() {
    try {
      const migrator = new Migrator({
        db: this.getConnection(),
        provider: new FileMigrationProvider({
          fs,
          path,
          migrationFolder: path.join(
            import.meta.dirname,
            '../../database/migrations',
          ),
        }),
      });

      const { error, results } = await migrator.migrateToLatest();

      if (results) {
        results.forEach((result) => {
          if (result.status === 'Success') {
            this.logger.log(
              `✅ Migration "${result.migrationName}" executed successfully`,
            );
          } else if (result.status === 'Error') {
            this.logger.error(`❌ Migration "${result.migrationName}" failed`);
          }
        });
      }

      if (error) {
        this.logger.error(error, '❌ Migration failed');
        throw error;
      }

      this.logger.log('🎉 All migrations completed successfully');
    } catch (error) {
      this.logger.error(error, '❌ Database initialization failed');
      throw error;
    }
    // No need to destroy db - it's managed by the DI container
  }

  async onApplicationShutdown(signal?: string) {
    if (this.db) {
      this.logger.log(`📊 Closing database connection (signal: ${signal})`);
      await this.db.destroy();
      this.db = null;
      this.logger.log('📊 Database connection closed');
    }
  }
}
