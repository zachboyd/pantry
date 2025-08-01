import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserModule } from '../user/user.module.js';
import { HouseholdApi } from './api/household.api.js';
import { HouseholdController } from './api/household.controller.js';
import { HouseholdResolver } from './api/household.resolver.js';
import { HouseholdRepositoryImpl } from './household.repository.js';
import { HouseholdServiceImpl } from './household.service.js';

@Module({
  imports: [UserModule],
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
      provide: TOKENS.HOUSEHOLD.API,
      useClass: HouseholdApi,
    },
  ],
  exports: [TOKENS.HOUSEHOLD.SERVICE, TOKENS.HOUSEHOLD.REPOSITORY, TOKENS.HOUSEHOLD.API],
})
export class HouseholdModule {}