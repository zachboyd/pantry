export interface EmailAddress {
  address: string;
  name?: string;
}

export interface EmailAttachment {
  filename: string;
  content: Buffer;
  contentType?: string;
}

export interface EmailOptions {
  to: string | string[] | EmailAddress | EmailAddress[];
  cc?: string | string[] | EmailAddress | EmailAddress[];
  bcc?: string | string[] | EmailAddress | EmailAddress[];
  subject: string;
  text?: string;
  html?: string;
  attachments?: EmailAttachment[];
  replyTo?: string | EmailAddress;
  from?: string | EmailAddress;
}

export interface EmailTemplate {
  name: string;
  subject: string;
  html: string;
  text?: string;
}

export interface EmailTemplateOptions {
  template: string;
  to: string | string[] | EmailAddress | EmailAddress[];
  variables?: Record<string, unknown>;
  cc?: string | string[] | EmailAddress | EmailAddress[];
  bcc?: string | string[] | EmailAddress | EmailAddress[];
  replyTo?: string | EmailAddress;
  from?: string | EmailAddress;
  debug?: Record<string, unknown>;
}

export interface EmailSendResult {
  messageId: string;
  accepted: string[];
  rejected: string[];
}

export interface EmailTemplateFile {
  name: string;
  subject: string;
  html: string;
  text?: string;
  description?: string;
}

export interface EmailTemplateRegistry {
  [key: string]: () => EmailTemplateFile;
}

export interface EmailConfig {
  region: string;
  fromAddress: string;
  configurationSetName?: string;
  credentials?: {
    accessKeyId: string;
    secretAccessKey: string;
  };
}

export interface EmailService {
  sendEmail(options: EmailOptions): Promise<EmailSendResult>;

  sendTemplateEmail(options: EmailTemplateOptions): Promise<EmailSendResult>;

  registerTemplate(template: EmailTemplate): void;

  getTemplate(name: string): EmailTemplate | undefined;

  validateEmail(email: string): boolean;

  loadTemplatesFromRegistry(registry: EmailTemplateRegistry): Promise<void>;
}
