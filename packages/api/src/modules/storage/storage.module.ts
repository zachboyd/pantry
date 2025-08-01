import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import { FileStorageFactoryImpl } from './storage.factory.js';
import type { FileStorageService } from './storage.types.js';

@Module({
  imports: [AppConfigModule],
  providers: [
    {
      provide: TOKENS.STORAGE.FACTORY,
      useClass: FileStorageFactoryImpl,
    },
    {
      provide: TOKENS.STORAGE.SERVICE,
      useFactory: (factory: FileStorageFactoryImpl): FileStorageService => {
        return factory.createStorageService();
      },
      inject: [TOKENS.STORAGE.FACTORY],
    },
  ],
  exports: [TOKENS.STORAGE.SERVICE, TOKENS.STORAGE.FACTORY],
})
export class StorageModule {}