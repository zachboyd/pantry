import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { DatabaseModule } from '../database/database.module.js';
import { UserRepositoryImpl } from './user.repository.js';

/**
 * User Repository Module
 *
 * Provides only the UserRepository for data access.
 * Use this module when you need user data access without business logic.
 *
 * This avoids circular dependencies since it doesn't depend on other feature modules.
 */
@Module({
  imports: [DatabaseModule],
  providers: [
    {
      provide: TOKENS.USER.REPOSITORY,
      useClass: UserRepositoryImpl,
    },
  ],
  exports: [TOKENS.USER.REPOSITORY],
})
export class UserRepositoryModule {}
