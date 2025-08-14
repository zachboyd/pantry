export const EMAIL_TEMPLATES = {
  EMAIL_VERIFICATION: 'email-verification',
  EMAIL_CHANGE_VERIFICATION: 'email-change-verification',
} as const;

export type EmailTemplateKey =
  (typeof EMAIL_TEMPLATES)[keyof typeof EMAIL_TEMPLATES];
