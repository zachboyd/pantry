import type { EmailTemplateFile } from '../email.types.js';

export const emailChangeVerificationTemplate = (): EmailTemplateFile => ({
  name: 'email-change-verification',
  subject: 'Approve email change for {{appName}}',
  description:
    'Template for email change verification. Sent to current email address to approve change to new email address.',
  // Better Auth provides: user (with user.name, user.email), newEmail, url, token
  // Our template variables: userName, currentEmail, newEmail, verificationUrl, appName, expiryHours, supportEmail
  html: `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Approve Email Change</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; background-color: #f4f4f4;">
      <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1); overflow: hidden;">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px; font-weight: 600;">{{appName}}</h1>
          <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Approve email change</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <h2 style="color: #333; margin: 0 0 20px 0; font-size: 24px;">Hi {{userName}}!</h2>
          
          <p style="margin: 0 0 20px 0; font-size: 16px; color: #555;">
            You requested to change your email address for your {{appName}} account. To complete this change, please verify this request by clicking the button below.
          </p>
          
          <!-- Email Change Details -->
          <div style="background-color: #f8f9fa; border-radius: 6px; padding: 20px; margin: 20px 0; border-left: 4px solid #667eea;">
            <p style="margin: 0 0 10px 0; font-size: 16px; color: #555;">
              <strong>Current email:</strong> {{currentEmail}}
            </p>
            <p style="margin: 0; font-size: 16px; color: #555;">
              <strong>New email:</strong> {{newEmail}}
            </p>
          </div>
          
          <!-- CTA Button -->
          <div style="text-align: center; margin: 30px 0;">
            <a href="{{verificationUrl}}" 
               style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; padding: 15px 30px; border-radius: 6px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3); transition: transform 0.2s ease;">
              Approve Email Change
            </a>
          </div>
          
          <div style="border-top: 1px solid #eee; margin: 30px 0; padding-top: 20px;">
            <p style="margin: 0 0 15px 0; font-size: 14px; color: #666;">
              <strong>Having trouble with the button?</strong> Copy and paste this link into your browser:
            </p>
            <p style="margin: 0; font-size: 14px; color: #667eea; word-break: break-all;">
              {{verificationUrl}}
            </p>
          </div>
          
          <!-- Security Notice -->
          <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; border-radius: 6px; padding: 20px; margin: 20px 0;">
            <p style="margin: 0 0 10px 0; font-size: 14px; color: #856404;">
              🔒 <strong>Security Notice:</strong> This verification link will expire in {{expiryHours}} hours.
            </p>
            <p style="margin: 0; font-size: 14px; color: #856404;">
              ⚠️ If you didn't request this email change, please ignore this email and consider changing your password.
            </p>
          </div>
          
          <div style="background-color: #f8f9fa; border-radius: 6px; padding: 15px; margin: 20px 0;">
            <p style="margin: 0; font-size: 14px; color: #666;">
              💡 <strong>Note:</strong> Your current email will remain active until you approve this change. After approval, you'll receive a confirmation at your new email address.
            </p>
          </div>
        </div>
        
        <!-- Footer -->
        <div style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #eee;">
          <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">
            Need help? Contact us at <a href="mailto:{{supportEmail}}" style="color: #667eea; text-decoration: none;">{{supportEmail}}</a>
          </p>
          <p style="margin: 0; font-size: 12px; color: #999;">
            © 2025 {{appName}}. All rights reserved.
          </p>
        </div>
      </div>
    </body>
    </html>
  `,
  text: `
Hi {{userName}}!

You requested to change your email address for your {{appName}} account.

Current email: {{currentEmail}}
New email: {{newEmail}}

To complete this change, please approve the request by clicking this link:
{{verificationUrl}}

SECURITY NOTICE:
- This verification link will expire in {{expiryHours}} hours
- If you didn't request this email change, please ignore this email and consider changing your password
- Your current email will remain active until you approve this change

Need help? Contact us at {{supportEmail}}

© 2025 {{appName}}. All rights reserved.
  `.trim(),
});
