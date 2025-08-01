import { Inject, Injectable, Logger } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import type { ConfigService } from '../config/config.types.js';
import type { FileStorageService, FileStorageFactory, StorageBackend } from './storage.types.js';
import { S3StorageServiceImpl } from './implementations/s3-storage.service.js';

@Injectable()
export class FileStorageFactoryImpl implements FileStorageFactory {
  private readonly logger = new Logger(FileStorageFactoryImpl.name);

  constructor(
    @Inject(TOKENS.CONFIG.SERVICE)
    private readonly configService: ConfigService,
  ) {}

  createStorageService(): FileStorageService {
    const backend = this.getStorageBackend();

    switch (backend) {
      case 's3':
        this.logger.debug('Creating S3 storage service');
        return new S3StorageServiceImpl(this.configService);
      
      case 'gcs':
        throw new Error('Google Cloud Storage not yet implemented');
      
      case 'azure':
        throw new Error('Azure Blob Storage not yet implemented');
      
      default:
        throw new Error(`Unsupported storage backend: ${backend}`);
    }
  }

  private getStorageBackend(): StorageBackend {
    // For now, we'll default to S3. In the future, this could be configurable
    // via environment variables or configuration service
    return 's3' as StorageBackend;
  }
}