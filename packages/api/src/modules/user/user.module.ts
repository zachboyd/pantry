import { Module, forwardRef } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserRepositoryModule } from './user-repository.module.js';
import { UserServiceImpl } from './user.service.js';
import { GuardedUserService } from './api/guarded-user.service.js';
import { UserResolver } from './api/user.resolver.js';
import { UserController } from './api/user.controller.js';
import { PermissionModule } from '../permission/permission.module.js';

@Module({
  imports: [UserRepositoryModule, forwardRef(() => PermissionModule)],
  controllers: [UserController],
  providers: [
    {
      provide: TOKENS.USER.SERVICE,
      useClass: UserServiceImpl,
    },
    {
      provide: TOKENS.USER.GUARDED_SERVICE,
      useClass: GuardedUserService,
    },
    UserResolver,
  ],
  exports: [TOKENS.USER.SERVICE, TOKENS.USER.GUARDED_SERVICE],
})
export class UserModule {}
