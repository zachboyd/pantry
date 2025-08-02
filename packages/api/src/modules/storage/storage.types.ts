export interface UploadOptions {
  expiresIn?: number;
  contentType?: string;
  metadata?: Record<string, string>;
}

export interface DownloadOptions {
  expiresIn?: number;
  responseContentType?: string;
  responseContentDisposition?: string;
}

export interface FileStorageService {
  generateUploadUrl(
    key: string,
    contentType: string,
    options?: UploadOptions,
  ): Promise<string>;

  generateDownloadUrl(key: string, options?: DownloadOptions): Promise<string>;

  deleteFile(key: string): Promise<void>;

  generateFileKey(namespace: string, filename: string): string;
}

export enum StorageBackend {
  S3 = 's3',
  GCS = 'gcs',
  AZURE = 'azure',
}

export interface FileStorageFactory {
  createStorageService(): FileStorageService;
}
