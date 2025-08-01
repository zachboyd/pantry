import {
  Body,
  Controller,
  Delete,
  Get,
  Inject,
  Logger,
  Param,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import {
  ApiOperation,
  ApiResponse,
  ApiSecurity,
  ApiTags,
} from '@nestjs/swagger';
import { TOKENS } from '../../common/tokens.js';
import { User } from '../auth/auth.decorator.js';
import type { UserRecord } from '../user/user.types.js';
import type {
  AttachmentService,
  AttachmentUploadConfirmation,
  DownloadUrlRequest,
  DownloadUrlResponse,
  UploadUrlRequest,
  UploadUrlResponse,
} from './attachment.types.js';

@ApiTags('attachments')
@Controller('api/attachments')
export class AttachmentController {
  private readonly logger = new Logger(AttachmentController.name);

  constructor(
    @Inject(TOKENS.ATTACHMENT.SERVICE)
    private readonly attachmentService: AttachmentService,
  ) {}

  @Post('upload-url')
  @ApiOperation({ summary: 'Generate presigned URL for attachment upload' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Presigned upload URL generated',
    schema: {
      type: 'object',
      properties: {
        id: { type: 'string' },
        upload_url: { type: 'string' },
        s3_key: { type: 'string' },
        expires_at: { type: 'number' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({ status: 403, description: 'Forbidden - Access denied to household' })
  async createUploadUrl(
    @Body() request: UploadUrlRequest,
    @User() user: UserRecord | null,
  ): Promise<UploadUrlResponse> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(
        `Creating upload URL for file: ${request.filename} in household: ${request.household_id}`,
      );

      const result = await this.attachmentService.createUploadUrl(request, user);

      this.logger.log(`Generated upload URL for attachment: ${result.id}`);

      return result;
    } catch (error) {
      this.logger.error(error, 'Failed to create upload URL');
      throw error;
    }
  }

  @Post(':id/uploaded')
  @ApiOperation({ summary: 'Confirm successful attachment upload' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Upload confirmed successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({ status: 403, description: 'Forbidden - Access denied to household' })
  @ApiResponse({ status: 404, description: 'Not Found - Attachment not found' })
  async confirmUpload(
    @Param('id') attachmentId: string,
    @Body() body: { s3_key: string },
    @User() user: UserRecord | null,
  ): Promise<void> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(`Confirming upload for attachment: ${attachmentId}`);

      const confirmation: AttachmentUploadConfirmation = {
        attachment_id: attachmentId,
        s3_key: body.s3_key,
      };

      await this.attachmentService.confirmUpload(confirmation, user);

      this.logger.log(`Upload confirmed for attachment: ${attachmentId}`);
    } catch (error) {
      this.logger.error(error, 'Failed to confirm upload');
      throw error;
    }
  }

  @Get(':id/download-url')
  @ApiOperation({ summary: 'Generate presigned URL for attachment download' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Presigned download URL generated',
    schema: {
      type: 'object',
      properties: {
        download_url: { type: 'string' },
        expires_at: { type: 'number' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({ status: 403, description: 'Forbidden - Access denied to household' })
  @ApiResponse({ status: 404, description: 'Not Found - Attachment not found' })
  async createDownloadUrl(
    @Param('id') attachmentId: string,
    @User() user: UserRecord | null,
  ): Promise<DownloadUrlResponse> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(`Creating download URL for attachment: ${attachmentId}`);

      const request: DownloadUrlRequest = {
        attachment_id: attachmentId,
      };

      const result = await this.attachmentService.createDownloadUrl(request, user);

      this.logger.log(`Generated download URL for attachment: ${attachmentId}`);

      return result;
    } catch (error) {
      this.logger.error(error, 'Failed to create download URL');
      throw error;
    }
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete attachment and associated file' })
  @ApiSecurity('session')
  @ApiResponse({
    status: 200,
    description: 'Attachment deleted successfully',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized - User not found' })
  @ApiResponse({ status: 403, description: 'Forbidden - Access denied to household' })
  @ApiResponse({ status: 404, description: 'Not Found - Attachment not found' })
  async deleteAttachment(
    @Param('id') attachmentId: string,
    @User() user: UserRecord | null,
  ): Promise<void> {
    try {
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      this.logger.log(`Deleting attachment: ${attachmentId}`);

      await this.attachmentService.deleteAttachment(attachmentId, user);

      this.logger.log(`Deleted attachment: ${attachmentId}`);
    } catch (error) {
      this.logger.error(error, 'Failed to delete attachment');
      throw error;
    }
  }
}