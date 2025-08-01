import { Module } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import { DatabaseModule } from '../database/database.module.js';
import { StorageModule } from '../storage/storage.module.js';
import { AttachmentController } from './attachment.controller.js';
import { AttachmentRepositoryImpl } from './attachment.repository.js';
import { AttachmentServiceImpl } from './attachment.service.js';

@Module({
  imports: [DatabaseModule, StorageModule],
  controllers: [AttachmentController],
  providers: [
    {
      provide: TOKENS.ATTACHMENT.REPOSITORY,
      useClass: AttachmentRepositoryImpl,
    },
    {
      provide: TOKENS.ATTACHMENT.SERVICE,
      useClass: AttachmentServiceImpl,
    },
  ],
  exports: [
    TOKENS.ATTACHMENT.SERVICE,
    TOKENS.ATTACHMENT.REPOSITORY,
  ],
})
export class AttachmentModule {}