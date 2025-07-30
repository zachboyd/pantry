import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AuthModule } from '../auth/auth.module.js';
import { DatabaseModule } from '../database/database.module.js';
import { MessageModule } from '../message/message.module.js';
import { UserModule } from '../user/user.module.js';
import { PowerSyncController } from './powersync.controller.js';
import { PowerSyncAuthServiceImpl } from './powersync-auth.service.js';
import { PowerSyncOperationServiceImpl } from './powersync-operation.service.js';

@Module({
  imports: [AuthModule, DatabaseModule, MessageModule, UserModule],
  controllers: [PowerSyncController],
  providers: [
    {
      provide: TOKENS.POWERSYNC.AUTH_SERVICE,
      useClass: PowerSyncAuthServiceImpl,
    },
    {
      provide: TOKENS.POWERSYNC.OPERATION_SERVICE,
      useClass: PowerSyncOperationServiceImpl,
    },
  ],
  exports: [TOKENS.POWERSYNC.AUTH_SERVICE, TOKENS.POWERSYNC.OPERATION_SERVICE],
})
export class PowerSyncModule {}
