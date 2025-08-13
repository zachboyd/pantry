import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { AppConfigModule } from '../config/config.module.js';
import { FileStorageFactoryImpl } from './storage.factory.js';
import { S3StorageServiceImpl } from './implementations/s3-storage.service.js';
import type { FileStorageService, S3Config } from './storage.types.js';
import type { ConfigService } from '../config/config.types.js';

@Module({
  imports: [AppConfigModule],
  providers: [
    {
      provide: TOKENS.STORAGE.S3_CONFIG,
      useFactory: (configService: ConfigService): S3Config => {
        const { aws } = configService.config;
        return {
          region: aws.region,
          bucketName: aws.s3.bucketName,
          credentials: aws.accessKeyId
            ? {
                accessKeyId: aws.accessKeyId,
                secretAccessKey: aws.secretAccessKey!,
              }
            : undefined,
        };
      },
      inject: [TOKENS.CONFIG.SERVICE],
    },
    {
      provide: TOKENS.STORAGE.S3_IMPL,
      useClass: S3StorageServiceImpl,
    },
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
