import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { PermissionServiceImpl } from './permission.service.js';
import { PermissionEventHandler } from './permission.event-handler.js';

@Module({
  providers: [
    {
      provide: TOKENS.PERMISSION.SERVICE,
      useClass: PermissionServiceImpl,
    },
    PermissionEventHandler,
  ],
  exports: [TOKENS.PERMISSION.SERVICE],
})
export class PermissionModule {}
