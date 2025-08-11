import type { EmailTemplateFile } from '../email.types.js';

export const emailVerificationTemplate = (): EmailTemplateFile => ({
  name: 'email-verification',
  subject: 'Verify your email address for {{appName}}',
  description:
    'Template for email address verification with confirmation link. Compatible with Better Auth integration.',
  // Better Auth provides: user (with user.name, user.email), url, token
  // Our template variables: userName, userEmail, verificationUrl, appName, expiryHours, supportEmail
  html: `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Verify Your Email</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; background-color: #f4f4f4;">
      <div style="max-width: 600px; margin: 20px auto; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1); overflow: hidden;">
        <!-- Header -->
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center;">
          <h1 style="margin: 0; font-size: 28px; font-weight: 600;">{{appName}}</h1>
          <p style="margin: 10px 0 0 0; font-size: 16px; opacity: 0.9;">Verify your email address</p>
        </div>
        
        <!-- Content -->
        <div style="padding: 40px 30px;">
          <h2 style="color: #333; margin: 0 0 20px 0; font-size: 24px;">Hi {{userName}}!</h2>
          
          <p style="margin: 0 0 20px 0; font-size: 16px; color: #555;">
            Thanks for signing up for {{appName}}! To complete your registration, please verify your email address by clicking the button below.
          </p>
          
          <p style="margin: 0 0 30px 0; font-size: 16px; color: #555;">
            Your email: <strong>{{userEmail}}</strong>
          </p>
          
          <!-- CTA Button -->
          <div style="text-align: center; margin: 30px 0;">
            <a href="{{verificationUrl}}" 
               style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-decoration: none; padding: 15px 30px; border-radius: 6px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 15px rgba(102, 126, 234, 0.3); transition: transform 0.2s ease;">
              Verify Email Address
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
          
          <div style="background-color: #f8f9fa; border-radius: 6px; padding: 20px; margin: 20px 0;">
            <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">
              ⏱️ <strong>Important:</strong> This verification link will expire in {{expiryHours}} hours for security reasons.
            </p>
            <p style="margin: 0; font-size: 14px; color: #666;">
              🔒 If you didn't create an account with us, you can safely ignore this email.
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

Thanks for signing up for {{appName}}! To complete your registration, please verify your email address.

Your email: {{userEmail}}

Verify your email by clicking this link:
{{verificationUrl}}

Important: This verification link will expire in {{expiryHours}} hours for security reasons.

If you didn't create an account with us, you can safely ignore this email.

Need help? Contact us at {{supportEmail}}

© 2025 {{appName}}. All rights reserved.
  `.trim(),
});
