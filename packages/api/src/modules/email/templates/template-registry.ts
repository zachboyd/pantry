import type { EmailTemplateRegistry } from '../email.types.js';
import { emailVerificationTemplate } from './email-verification.template.js';
import { EMAIL_TEMPLATES } from './template-constants.js';

export const templateRegistry: EmailTemplateRegistry = {
  [EMAIL_TEMPLATES.EMAIL_VERIFICATION]: emailVerificationTemplate,
};
