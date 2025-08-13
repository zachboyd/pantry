export const EMAIL_TEMPLATES = {
  EMAIL_VERIFICATION: 'email-verification',
} as const;

export type EmailTemplateKey =
  (typeof EMAIL_TEMPLATES)[keyof typeof EMAIL_TEMPLATES];
