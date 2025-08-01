import {
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { Kysely } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { DB } from '../../generated/database.js';
import type { UserRecord } from '../user/user.types.js';
import type { FileStorageService } from '../storage/storage.types.js';
import { AttachmentState } from './attachment.types.js';
import type {
  AttachmentRecord,
  AttachmentRepository,
  AttachmentService,
  AttachmentUploadConfirmation,
  DownloadUrlRequest,
  DownloadUrlResponse,
  UploadUrlRequest,
  UploadUrlResponse,
} from './attachment.types.js';

@Injectable()
export class AttachmentServiceImpl implements AttachmentService {
  private readonly logger = new Logger(AttachmentServiceImpl.name);

  constructor(
    @Inject(TOKENS.ATTACHMENT.REPOSITORY)
    private readonly attachmentRepository: AttachmentRepository,
    @Inject(TOKENS.STORAGE.SERVICE)
    private readonly storageService: FileStorageService,
    @Inject(TOKENS.DATABASE.CONNECTION)
    private readonly db: Kysely<DB>,
  ) {}

  async createUploadUrl(
    request: UploadUrlRequest,
    user: UserRecord,
  ): Promise<UploadUrlResponse> {
    this.logger.log(
      `Creating upload URL for file: ${request.filename} in household: ${request.household_id}`,
    );

    // Verify user has access to the household
    await this.verifyHouseholdAccess(user.id, request.household_id);

    // Generate storage key with household namespace and random component
    const storageKey = this.storageService.generateFileKey(
      `attachments/${request.household_id}`,
      request.filename,
    );

    // Generate presigned upload URL
    const uploadUrl = await this.storageService.generateUploadUrl(
      storageKey,
      request.media_type,
      { expiresIn: 900 }, // 15 minutes
    );

    // Create attachment record in database
    const attachmentId = randomUUID();
    const attachment = await this.attachmentRepository.create({
      id: attachmentId,
      filename: request.filename,
      media_type: request.media_type,
      size: request.size,
      state: AttachmentState.QUEUED_UPLOAD,
      household_id: request.household_id,
      user_id: user.id,
      timestamp: Date.now(),
      local_uri: storageKey, // Store the storage key for later retrieval
    });

    const expiresAt = Math.floor(Date.now() / 1000) + 900; // 15 minutes from now

    this.logger.log(
      `Created upload URL for attachment: ${attachment.id} with storage key: ${storageKey}`,
    );

    return {
      id: attachment.id,
      upload_url: uploadUrl,
      s3_key: storageKey, // Keep s3_key name for API compatibility
      expires_at: expiresAt,
    };
  }

  async confirmUpload(
    confirmation: AttachmentUploadConfirmation,
    user: UserRecord,
  ): Promise<void> {
    this.logger.log(`Confirming upload for attachment: ${confirmation.attachment_id}`);

    const attachment = await this.attachmentRepository.findById(
      confirmation.attachment_id,
    );

    if (!attachment) {
      throw new NotFoundException('Attachment not found');
    }

    // Verify user has access to the household
    await this.verifyHouseholdAccess(user.id, attachment.household_id);

    // Update attachment state to synced
    await this.attachmentRepository.update(confirmation.attachment_id, {
      state: AttachmentState.SYNCED,
    });

    this.logger.log(`Upload confirmed for attachment: ${confirmation.attachment_id}`);
  }

  async createDownloadUrl(
    request: DownloadUrlRequest,
    user: UserRecord,
  ): Promise<DownloadUrlResponse> {
    this.logger.log(`Creating download URL for attachment: ${request.attachment_id}`);

    const attachment = await this.attachmentRepository.findById(
      request.attachment_id,
    );

    if (!attachment) {
      throw new NotFoundException('Attachment not found');
    }

    // Verify user has access to the household
    await this.verifyHouseholdAccess(user.id, attachment.household_id);

    // Get storage key from the attachment record
    const storageKey = attachment.local_uri;
    if (!storageKey) {
      throw new NotFoundException('Attachment storage key not found');
    }

    // Generate presigned download URL
    const downloadUrl = await this.storageService.generateDownloadUrl(storageKey, {
      expiresIn: 3600, // 1 hour
    });

    const expiresAt = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    this.logger.log(`Created download URL for attachment: ${attachment.id}`);

    return {
      download_url: downloadUrl,
      expires_at: expiresAt,
    };
  }

  async deleteAttachment(attachmentId: string, user: UserRecord): Promise<void> {
    this.logger.log(`Deleting attachment: ${attachmentId}`);

    const attachment = await this.attachmentRepository.findById(attachmentId);

    if (!attachment) {
      throw new NotFoundException('Attachment not found');
    }

    // Verify user has access to the household
    await this.verifyHouseholdAccess(user.id, attachment.household_id);

    // Get storage key from the attachment record
    const storageKey = attachment.local_uri;
    if (storageKey) {
      try {
        // Delete from storage
        await this.storageService.deleteFile(storageKey);
      } catch (error) {
        this.logger.warn(`Failed to delete storage object: ${storageKey}`, error);
        // Continue with database deletion even if storage deletion fails
      }
    }

    // Delete from database
    await this.attachmentRepository.delete(attachmentId);

    this.logger.log(`Deleted attachment: ${attachmentId}`);
  }

  async getAttachmentsByHousehold(
    householdId: string,
    user: UserRecord,
  ): Promise<AttachmentRecord[]> {
    this.logger.log(`Getting attachments for household: ${householdId}`);

    // Verify user has access to the household
    await this.verifyHouseholdAccess(user.id, householdId);

    const attachments = await this.attachmentRepository.findByHouseholdId(
      householdId,
    );

    this.logger.log(
      `Retrieved ${attachments.length} attachments for household: ${householdId}`,
    );

    return attachments;
  }

  private async verifyHouseholdAccess(
    userId: string,
    householdId: string,
  ): Promise<void> {
    const membership = await this.db
      .selectFrom('household_member')
      .select('id')
      .where('user_id', '=', userId)
      .where('household_id', '=', householdId)
      .executeTakeFirst();

    if (!membership) {
      throw new ForbiddenException('Access denied to household');
    }
  }
}