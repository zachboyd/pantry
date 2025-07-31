import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { HouseholdRepositoryImpl } from './household.repository.js';
import { HouseholdServiceImpl } from './household.service.js';

@Module({
  providers: [
    {
      provide: TOKENS.HOUSEHOLD.REPOSITORY,
      useClass: HouseholdRepositoryImpl,
    },
    {
      provide: TOKENS.HOUSEHOLD.SERVICE,
      useClass: HouseholdServiceImpl,
    },
  ],
  exports: [TOKENS.HOUSEHOLD.SERVICE, TOKENS.HOUSEHOLD.REPOSITORY],
})
export class HouseholdModule {}