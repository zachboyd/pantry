import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { UserRepositoryModule } from './user-repository.module.js';
import { UserServiceImpl } from './user.service.js';

@Module({
  imports: [UserRepositoryModule],
  providers: [
    {
      provide: TOKENS.USER.SERVICE,
      useClass: UserServiceImpl,
    },
  ],
  exports: [TOKENS.USER.SERVICE],
})
export class UserModule {}
