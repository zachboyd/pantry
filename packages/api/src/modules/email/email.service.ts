import { Injectable, Inject, Logger, OnModuleInit } from '@nestjs/common';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { TOKENS } from '../../common/tokens.js';
import type {
  EmailService,
  EmailOptions,
  EmailTemplateOptions,
  EmailTemplate,
  EmailSendResult,
  EmailAddress,
  EmailTemplateRegistry,
  EmailConfig,
} from './email.types.js';
import { templateRegistry } from './templates/template-registry.js';

@Injectable()
export class EmailServiceImpl implements EmailService, OnModuleInit {
  private readonly logger = new Logger(EmailServiceImpl.name);
  private readonly sesClient: SESClient;
  private readonly templates = new Map<string, EmailTemplate>();

  constructor(
    @Inject(TOKENS.EMAIL.CONFIG)
    private readonly emailConfig: EmailConfig,
  ) {
    this.sesClient = new SESClient({
      region: this.emailConfig.region,
      credentials: this.emailConfig.credentials,
    });
  }

  async onModuleInit() {
    await this.loadTemplatesFromRegistry(templateRegistry);
  }

  async sendEmail(options: EmailOptions): Promise<EmailSendResult> {
    try {
      this.logger.debug('Preparing to send email', {
        to: this.normalizeAddresses(options.to),
        subject: options.subject,
      });

      const emailParams = {
        Destination: {
          ToAddresses: this.normalizeAddresses(options.to),
          CcAddresses: options.cc
            ? this.normalizeAddresses(options.cc)
            : undefined,
          BccAddresses: options.bcc
            ? this.normalizeAddresses(options.bcc)
            : undefined,
        },
        Message: {
          Subject: {
            Charset: 'UTF-8',
            Data: options.subject,
          },
          Body: {
            ...(options.html && {
              Html: {
                Charset: 'UTF-8',
                Data: options.html,
              },
            }),
            ...(options.text && {
              Text: {
                Charset: 'UTF-8',
                Data: options.text,
              },
            }),
          },
        },
        Source: this.normalizeAddress(
          options.from || this.emailConfig.fromAddress,
        ),
        ...(options.replyTo && {
          ReplyToAddresses: [this.normalizeAddress(options.replyTo)],
        }),
        ...(this.emailConfig.configurationSetName && {
          ConfigurationSetName: this.emailConfig.configurationSetName,
        }),
      };

      const command = new SendEmailCommand(emailParams);
      const result = await this.sesClient.send(command);

      const successResult: EmailSendResult = {
        messageId: result.MessageId!,
        accepted: this.normalizeAddresses(options.to),
        rejected: [],
      };

      this.logger.log('Email sent successfully', {
        messageId: result.MessageId,
        to: successResult.accepted,
      });

      return successResult;
    } catch (error) {
      this.logger.error('Failed to send email', {
        error: error.message,
        to: this.normalizeAddresses(options.to),
        subject: options.subject,
      });
      throw error;
    }
  }

  async sendTemplateEmail(
    options: EmailTemplateOptions,
  ): Promise<EmailSendResult> {
    const template = this.getTemplate(options.template);
    if (!template) {
      throw new Error(`Email template '${options.template}' not found`);
    }

    const processedTemplate = this.processTemplate(
      template,
      options.variables || {},
    );

    const emailOptions: EmailOptions = {
      to: options.to,
      cc: options.cc,
      bcc: options.bcc,
      replyTo: options.replyTo,
      from: options.from,
      subject: processedTemplate.subject,
      html: processedTemplate.html,
      text: processedTemplate.text,
    };

    return this.sendEmail(emailOptions);
  }

  registerTemplate(template: EmailTemplate): void {
    this.templates.set(template.name, template);
    this.logger.debug('Email template registered', {
      templateName: template.name,
    });
  }

  getTemplate(name: string): EmailTemplate | undefined {
    return this.templates.get(name);
  }

  validateEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  async loadTemplatesFromRegistry(
    registry: EmailTemplateRegistry,
  ): Promise<void> {
    try {
      const templateKeys = Object.keys(registry);

      for (const key of templateKeys) {
        const templateFactory = registry[key];
        const templateFile = templateFactory();

        const template: EmailTemplate = {
          name: templateFile.name,
          subject: templateFile.subject,
          html: templateFile.html,
          text: templateFile.text,
        };

        this.templates.set(key, template);
        this.logger.debug('Template loaded from registry', {
          templateKey: key,
          templateName: templateFile.name,
          description: templateFile.description,
        });
      }

      this.logger.log(
        `Loaded ${templateKeys.length} email templates from registry`,
      );
    } catch (error) {
      this.logger.error('Failed to load templates from registry', {
        error: error.message,
      });
      throw error;
    }
  }

  private normalizeAddress(address: string | EmailAddress): string {
    if (typeof address === 'string') {
      return address;
    }
    return address.name
      ? `${address.name} <${address.address}>`
      : address.address;
  }

  private normalizeAddresses(
    addresses: string | string[] | EmailAddress | EmailAddress[],
  ): string[] {
    const addressArray = Array.isArray(addresses) ? addresses : [addresses];
    return addressArray.map((addr) => this.normalizeAddress(addr));
  }

  private processTemplate(
    template: EmailTemplate,
    variables: Record<string, unknown>,
  ): EmailTemplate {
    const replaceVariables = (text: string): string => {
      return text.replace(/\{\{(\w+)\}\}/g, (match, key) => {
        return variables[key] !== undefined ? String(variables[key]) : match;
      });
    };

    return {
      name: template.name,
      subject: replaceVariables(template.subject),
      html: replaceVariables(template.html),
      text: template.text ? replaceVariables(template.text) : undefined,
    };
  }
}
