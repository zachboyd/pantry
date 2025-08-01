import { Inject, Injectable } from '@nestjs/common';
import type { Kysely } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { DB } from '../../generated/database.js';
import type {
  AttachmentInsert,
  AttachmentRecord,
  AttachmentRepository,
  AttachmentUpdate,
} from './attachment.types.js';

@Injectable()
export class AttachmentRepositoryImpl implements AttachmentRepository {
  constructor(
    @Inject(TOKENS.DATABASE.CONNECTION)
    private readonly db: Kysely<DB>,
  ) {}

  async create(attachment: AttachmentInsert): Promise<AttachmentRecord> {
    return await this.db
      .insertInto('attachments')
      .values(attachment)
      .returningAll()
      .executeTakeFirstOrThrow();
  }

  async findById(id: string): Promise<AttachmentRecord | null> {
    return (
      (await this.db
        .selectFrom('attachments')
        .selectAll()
        .where('id', '=', id)
        .executeTakeFirst()) || null
    );
  }

  async findByHouseholdId(householdId: string): Promise<AttachmentRecord[]> {
    return await this.db
      .selectFrom('attachments')
      .selectAll()
      .where('household_id', '=', householdId)
      .orderBy('created_at', 'desc')
      .execute();
  }

  async update(
    id: string,
    updates: AttachmentUpdate,
  ): Promise<AttachmentRecord> {
    return await this.db
      .updateTable('attachments')
      .set(updates)
      .where('id', '=', id)
      .returningAll()
      .executeTakeFirstOrThrow();
  }

  async delete(id: string): Promise<void> {
    await this.db.deleteFrom('attachments').where('id', '=', id).execute();
  }
}