import type { Insertable, Selectable, Updateable } from 'kysely';
import type { Attachments } from '../../generated/database.js';
import type { UserRecord } from '../user/user.types.js';

export type AttachmentRecord = Selectable<Attachments>;
export type AttachmentInsert = Insertable<Attachments>;
export type AttachmentUpdate = Updateable<Attachments>;

export enum AttachmentState {
  QUEUED_SYNC = 0,
  QUEUED_UPLOAD = 1,
  QUEUED_DOWNLOAD = 2,
  SYNCED = 3,
  ARCHIVED = 4,
}

export interface UploadUrlRequest {
  filename: string;
  media_type: string;
  size: number;
  household_id: string;
}

export interface UploadUrlResponse {
  id: string;
  upload_url: string;
  s3_key: string;
  expires_at: number;
}

export interface DownloadUrlRequest {
  attachment_id: string;
}

export interface DownloadUrlResponse {
  download_url: string;
  expires_at: number;
}

export interface AttachmentUploadConfirmation {
  attachment_id: string;
  s3_key: string;
}


export interface AttachmentRepository {
  create(attachment: AttachmentInsert): Promise<AttachmentRecord>;
  findById(id: string): Promise<AttachmentRecord | null>;
  findByHouseholdId(householdId: string): Promise<AttachmentRecord[]>;
  update(id: string, updates: AttachmentUpdate): Promise<AttachmentRecord>;
  delete(id: string): Promise<void>;
}

export interface AttachmentService {
  createUploadUrl(
    request: UploadUrlRequest,
    user: UserRecord,
  ): Promise<UploadUrlResponse>;
  confirmUpload(
    confirmation: AttachmentUploadConfirmation,
    user: UserRecord,
  ): Promise<void>;
  createDownloadUrl(
    request: DownloadUrlRequest,
    user: UserRecord,
  ): Promise<DownloadUrlResponse>;
  deleteAttachment(attachmentId: string, user: UserRecord): Promise<void>;
  getAttachmentsByHousehold(
    householdId: string,
    user: UserRecord,
  ): Promise<AttachmentRecord[]>;
}