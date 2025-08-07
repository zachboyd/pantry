import { Module, forwardRef } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserModule } from '../user/user.module.js';
import { PermissionServiceImpl } from './permission.service.js';
import { PermissionEventHandler } from './permission.event-handler.js';

@Module({
  imports: [forwardRef(() => UserModule)],
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
