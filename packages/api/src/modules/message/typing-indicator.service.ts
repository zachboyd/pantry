import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Insertable } from 'kysely';
import { TOKENS } from '../../common/tokens.js';
import type { TypingIndicator } from '../../generated/database.js';
import type {
  TypingIndicatorRepository,
  TypingIndicatorService,
} from './message.types.js';

@Injectable()
export class TypingIndicatorServiceImpl implements TypingIndicatorService {
  private readonly logger = new Logger(TypingIndicatorServiceImpl.name);

  constructor(
    @Inject(TOKENS.MESSAGE.TYPING_INDICATOR_REPOSITORY)
    private readonly typingIndicatorRepository: TypingIndicatorRepository,
  ) {}

  async save(
    typingIndicator: Insertable<TypingIndicator>,
  ): Promise<TypingIndicator> {
    this.logger.log(
      `Processing typing indicator for user ${typingIndicator.user_id} in household ${typingIndicator.household_id}`,
    );

    try {
      const savedIndicator =
        await this.typingIndicatorRepository.save(typingIndicator);
      this.logger.log(
        `Typing indicator processed successfully: ${savedIndicator.id}`,
      );
      return savedIndicator;
    } catch (error) {
      this.logger.error(error, `Failed to process typing indicator:`);
      throw error;
    }
  }
}
