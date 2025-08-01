import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserModule } from '../user/user.module.js';
import { PermissionModule } from '../permission/permission.module.js';
import { HouseholdController } from './api/household.controller.js';
import { HouseholdResolver } from './api/household.resolver.js';
import { GuardedHouseholdService } from './api/guarded-household.service.js';
import { HouseholdRepositoryImpl } from './household.repository.js';
import { HouseholdServiceImpl } from './household.service.js';

@Module({
  imports: [UserModule, PermissionModule],
  controllers: [HouseholdController],
  providers: [
    HouseholdResolver,
    {
      provide: TOKENS.HOUSEHOLD.REPOSITORY,
      useClass: HouseholdRepositoryImpl,
    },
    {
      provide: TOKENS.HOUSEHOLD.SERVICE,
      useClass: HouseholdServiceImpl,
    },
    {
      provide: TOKENS.HOUSEHOLD.GUARDED_SERVICE,
      useClass: GuardedHouseholdService,
    },
  ],
  exports: [
    TOKENS.HOUSEHOLD.SERVICE,
    TOKENS.HOUSEHOLD.REPOSITORY,
    TOKENS.HOUSEHOLD.GUARDED_SERVICE,
  ],
})
export class HouseholdModule {}
