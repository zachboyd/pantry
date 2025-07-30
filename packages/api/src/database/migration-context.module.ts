import { Module } from '@nestjs/common';
import { DatabaseModule } from '../modules/database/database.module.js';
import { AuthModule } from '../modules/auth/auth.module.js';
import { AppConfigModule } from '../modules/config/config.module.js';

/**
 * Minimal NestJS module for migration scripts
 * Provides access to essential services without the full application overhead
 */
@Module({
  imports: [AppConfigModule, DatabaseModule, AuthModule],
  exports: [DatabaseModule, AuthModule, AppConfigModule],
})
export class MigrationContextModule {}
