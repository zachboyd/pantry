import { Global, Module } from '@nestjs/common';
import { DatabaseServiceImpl } from './database.service.js';
import type { DatabaseService } from './database.types.js';
import { TOKENS } from '../../common/tokens.js';

@Global()
@Module({
  providers: [
    {
      provide: TOKENS.DATABASE.SERVICE,
      useClass: DatabaseServiceImpl,
    },
    {
      provide: TOKENS.DATABASE.CONNECTION,
      useFactory: (databaseService: DatabaseService) =>
        databaseService.getConnection(),
      inject: [TOKENS.DATABASE.SERVICE],
    },
  ],
  exports: [TOKENS.DATABASE.CONNECTION, TOKENS.DATABASE.SERVICE],
})
export class DatabaseModule {}
