import { Inject, Injectable, Logger } from '@nestjs/common';
import {
  S3Client,
  DeleteObjectCommand,
  PutObjectCommandInput,
  GetObjectCommandInput,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { randomBytes } from 'crypto';
import { TOKENS } from '../../../common/tokens.js';
import type {
  FileStorageService,
  UploadOptions,
  DownloadOptions,
  S3Config,
} from '../storage.types.js';

@Injectable()
export class S3StorageServiceImpl implements FileStorageService {
  private readonly logger = new Logger(S3StorageServiceImpl.name);
  private readonly s3Client: S3Client;
  private readonly bucketName: string;

  constructor(
    @Inject(TOKENS.STORAGE.S3_CONFIG)
    private readonly s3Config: S3Config,
  ) {
    // Use AWS SDK default credential chain (supports SSO, profiles, env vars, IAM roles, etc.)
    this.s3Client = new S3Client({
      region: this.s3Config.region,
      credentials: this.s3Config.credentials,
    });

    this.bucketName = this.s3Config.bucketName;
  }

  async generateUploadUrl(
    key: string,
    contentType: string,
    options: UploadOptions = {},
  ): Promise<string> {
    const { expiresIn = 900, metadata } = options; // Default 15 minutes

    const commandOptions: PutObjectCommandInput = {
      Bucket: this.bucketName,
      Key: key,
      ContentType: contentType,
    };

    if (metadata) {
      commandOptions.Metadata = metadata;
    }

    const command = new PutObjectCommand(commandOptions);

    try {
      const signedUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn,
      });

      this.logger.debug(`Generated upload URL for key: ${key}`);
      return signedUrl;
    } catch (error) {
      this.logger.error(`Failed to generate upload URL for key: ${key}`, error);
      throw new Error('Failed to generate upload URL');
    }
  }

  async generateDownloadUrl(
    key: string,
    options: DownloadOptions = {},
  ): Promise<string> {
    const {
      expiresIn = 3600,
      responseContentType,
      responseContentDisposition,
    } = options; // Default 1 hour

    const commandOptions: GetObjectCommandInput = {
      Bucket: this.bucketName,
      Key: key,
    };

    if (responseContentType) {
      commandOptions.ResponseContentType = responseContentType;
    }

    if (responseContentDisposition) {
      commandOptions.ResponseContentDisposition = responseContentDisposition;
    }

    const command = new GetObjectCommand(commandOptions);

    try {
      const signedUrl = await getSignedUrl(this.s3Client, command, {
        expiresIn,
      });

      this.logger.debug(`Generated download URL for key: ${key}`);
      return signedUrl;
    } catch (error) {
      this.logger.error(
        `Failed to generate download URL for key: ${key}`,
        error,
      );
      throw new Error('Failed to generate download URL');
    }
  }

  async deleteFile(key: string): Promise<void> {
    const command = new DeleteObjectCommand({
      Bucket: this.bucketName,
      Key: key,
    });

    try {
      await this.s3Client.send(command);
      this.logger.debug(`Deleted file: ${key}`);
    } catch (error) {
      this.logger.error(`Failed to delete file: ${key}`, error);
      throw new Error('Failed to delete file');
    }
  }

  generateFileKey(namespace: string, filename: string): string {
    // Generate random prefix to prevent enumeration attacks
    const randomPrefix = randomBytes(16).toString('hex');

    // Sanitize filename to prevent path traversal
    const sanitizedFilename = this.sanitizeFilename(filename);

    return `${namespace}/${randomPrefix}/${sanitizedFilename}`;
  }

  private sanitizeFilename(filename: string): string {
    // Remove path separators and other potentially dangerous characters
    return filename
      .replace(/[\/\\]/g, '_')
      .replace(/[^\w\-_.]/g, '_')
      .substring(0, 255); // Limit length
  }
}
