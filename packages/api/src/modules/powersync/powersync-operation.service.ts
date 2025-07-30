import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { Message, TypingIndicator } from '../../generated/database.js';
import type { DatabaseService } from '../database/database.types.js';
import type {
  MessageService,
  TypingIndicatorService,
} from '../message/message.types.js';
import type {
  CrudEntry,
  PowerSyncOperationService,
  UserRecord,
  WriteBatchResponse,
  WriteOperationError,
} from './powersync.types.js';

@Injectable()
export class PowerSyncOperationServiceImpl
  implements PowerSyncOperationService
{
  private readonly logger = new Logger(PowerSyncOperationServiceImpl.name);

  constructor(
    @Inject(TOKENS.DATABASE.SERVICE)
    private readonly databaseService: DatabaseService,
    @Inject(TOKENS.MESSAGE.SERVICE)
    private readonly messageService: MessageService,
    @Inject(TOKENS.MESSAGE.TYPING_INDICATOR_SERVICE)
    private readonly typingIndicatorService: TypingIndicatorService,
  ) {}

  async processOperation(operation: CrudEntry): Promise<void> {
    this.logger.debug(
      `Processing operation: ${operation.op} on ${operation.table}/${operation.id}`,
    );

    switch (operation.op) {
      case 'PUT':
        await this.processPutOperation(operation);
        break;
      case 'PATCH':
        await this.processPatchOperation(operation);
        break;
      case 'DELETE':
        await this.processDeleteOperation(operation);
        break;
      default:
        throw new Error(`Unsupported operation type: ${operation.op}`);
    }

    this.logger.debug(
      `Successfully processed operation: ${operation.op} on ${operation.table}/${operation.id}`,
    );
  }

  async processOperations(
    operations: CrudEntry[],
    user: UserRecord,
  ): Promise<WriteBatchResponse> {
    this.logger.log(
      `Processing ${operations.length} operations for user ${user.id}`,
    );

    const errors: WriteOperationError[] = [];

    // Process operations in sequence to maintain consistency
    for (let i = 0; i < operations.length; i++) {
      const operation = operations[i];
      try {
        this.logger.debug(
          `Processing operation ${i}: ${operation.op} on ${operation.table}/${operation.id}`,
        );

        await this.processOperation(operation);

        this.logger.debug(
          `Successfully processed operation ${i}: ${operation.op} on ${operation.table}/${operation.id}`,
        );
      } catch (error) {
        this.logger.error(
          error,
          `Failed to process operation ${i}: ${operation.op} on ${operation.table}/${operation.id}`,
          {
            operation: {
              op: operation.op,
              table: operation.table,
              id: operation.id,
              opData: operation.opData,
            },
            // Include additional error details for database errors
            errorDetails:
              error instanceof Error
                ? {
                    message: error.message,
                    stack: error.stack,
                    name: error.name,
                    // Include any additional properties that might be on database errors
                    ...('code' in error ? { code: error.code } : {}),
                    ...('detail' in error ? { detail: error.detail } : {}),
                    ...('hint' in error ? { hint: error.hint } : {}),
                    ...('position' in error
                      ? { position: error.position }
                      : {}),
                    ...('constraint' in error
                      ? { constraint: error.constraint }
                      : {}),
                  }
                : error,
          },
        );

        errors.push({
          operation_id: i,
          message:
            error instanceof Error ? error.message : 'Unknown error occurred',
          code: 'OPERATION_FAILED',
        });
      }
    }

    const success = errors.length === 0;
    this.logger.log(
      `Completed ${operations.length} operations for user ${user.id}: ${success ? 'all successful' : `${errors.length} errors`}`,
    );

    return {
      success,
      errors: errors.length > 0 ? errors : undefined,
    };
  }

  private async processPutOperation(operation: CrudEntry): Promise<void> {
    if (!operation.opData) {
      throw new Error('PUT operation requires data');
    }

    // Special handling for message table - delegate to MessageService
    if (operation.table === 'message') {
      await this.messageService.save(operation.opData as Insertable<Message>);
      return;
    }

    // Special handling for typing_indicator table - delegate to TypingIndicatorService
    if (operation.table === 'typing_indicator') {
      await this.typingIndicatorService.save(
        operation.opData as Insertable<TypingIndicator>,
      );
      return;
    }

    // Generic upsert: insert or update if conflict on id
    const db = this.databaseService.getConnection();
    await (db as any)
      .insertInto(operation.table)
      .values(operation.opData)
      .onConflict((oc: any) => oc.column('id').doUpdateSet(operation.opData))
      .execute();
  }

  private async processPatchOperation(operation: CrudEntry): Promise<void> {
    if (!operation.opData) {
      throw new Error('PATCH operation requires data');
    }

    const db = this.databaseService.getConnection();
    const result = await (db as any)
      .updateTable(operation.table)
      .set(operation.opData)
      .where('id', '=', operation.id)
      .execute();

    // Check if any rows were affected
    if (result.length === 0 || result[0]?.numUpdatedRows === 0) {
      throw new Error(`No record found with id: ${operation.id}`);
    }
  }

  private async processDeleteOperation(operation: CrudEntry): Promise<void> {
    const db = this.databaseService.getConnection();
    const result = await (db as any)
      .deleteFrom(operation.table)
      .where('id', '=', operation.id)
      .execute();

    // Check if any rows were affected
    if (result.length === 0 || result[0]?.numDeletedRows === 0) {
      throw new Error(`No record found with id: ${operation.id}`);
    }
  }
}
