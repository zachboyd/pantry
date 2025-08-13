import { Injectable, Inject, Logger } from '@nestjs/common';
import { TOKENS } from '../../common/tokens.js';
import type {
  AuthUserService,
  AuthUserRepository,
  AuthUserRecord,
} from './auth-user.types.js';

@Injectable()
export class AuthUserServiceImpl implements AuthUserService {
  private readonly logger = new Logger(AuthUserServiceImpl.name);

  constructor(
    @Inject(TOKENS.AUTH.USER_REPOSITORY)
    private readonly authUserRepository: AuthUserRepository,
  ) {}

  async getById(id: string): Promise<AuthUserRecord | null> {
    this.logger.debug(`Getting auth user by ID: ${id}`);

    try {
      return await this.authUserRepository.getById(id);
    } catch (error) {
      this.logger.error(`Error getting auth user by ID ${id}:`, error);
      throw error;
    }
  }

  async getByEmail(email: string): Promise<AuthUserRecord | null> {
    this.logger.debug(`Getting auth user by email: ${email}`);

    try {
      return await this.authUserRepository.getByEmail(email);
    } catch (error) {
      this.logger.error(`Error getting auth user by email ${email}:`, error);
      throw error;
    }
  }
}
