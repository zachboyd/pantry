import { Injectable, Logger } from '@nestjs/common';
import type {
  EmailService,
  EmailOptions,
  EmailTemplateOptions,
  EmailTemplate,
  EmailSendResult,
  EmailTemplateRegistry,
} from './email.types.js';
import { normalizeEmailAddresses } from './email.utils.js';

@Injectable()
export class MockEmailService implements EmailService {
  private readonly logger = new Logger(MockEmailService.name);

  async sendEmail(options: EmailOptions): Promise<EmailSendResult> {
    this.logger.log(
      {
        to: options.to,
        cc: options.cc,
        bcc: options.bcc,
        from: options.from,
        replyTo: options.replyTo,
        subject: options.subject,
        hasHtml: !!options.html,
        hasText: !!options.text,
      },
      '[MOCK EMAIL] sendEmail called with arguments:',
    );

    // Return mock success result
    return {
      messageId: `mock-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      accepted: normalizeEmailAddresses(options.to),
      rejected: [],
    };
  }

  async sendTemplateEmail(
    options: EmailTemplateOptions,
  ): Promise<EmailSendResult> {
    this.logger.log(
      {
        to: options.to,
        cc: options.cc,
        bcc: options.bcc,
        from: options.from,
        replyTo: options.replyTo,
        template: options.template,
        variables: options.variables,
      },
      '[MOCK EMAIL] sendTemplateEmail called with arguments:',
    );

    // Log debug information if provided
    if (options.debug) {
      this.logger.log(options.debug, '[MOCK EMAIL DEBUG]');
    }

    // Return mock success result
    return {
      messageId: `mock-template-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`,
      accepted: normalizeEmailAddresses(options.to),
      rejected: [],
    };
  }

  registerTemplate(template: EmailTemplate): void {
    this.logger.log(
      {
        name: template.name,
        subject: template.subject,
      },
      '[MOCK EMAIL] registerTemplate called:',
    );
  }

  getTemplate(name: string): EmailTemplate | undefined {
    this.logger.log({ name }, '[MOCK EMAIL] getTemplate called:');
    return undefined; // Mock doesn't need real templates
  }

  validateEmail(email: string): boolean {
    const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    this.logger.log({ email, isValid }, '[MOCK EMAIL] validateEmail called:');
    return isValid;
  }

  async loadTemplatesFromRegistry(
    registry: EmailTemplateRegistry,
  ): Promise<void> {
    this.logger.log(
      {
        templateCount: Object.keys(registry).length,
      },
      '[MOCK EMAIL] loadTemplatesFromRegistry called:',
    );
  }
}
