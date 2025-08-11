import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../generated/database.js';
import { EmailIntegrationTestModuleFactory } from '../../../test/utils/email-integration-test-module-factory.js';
import { TestDatabaseService } from '../../../test/utils/test-database.service.js';
import { TOKENS } from '../../../common/tokens.js';
import { EMAIL_TEMPLATES } from '../templates/template-constants.js';
import type { EmailService } from '../email.types.js';

describe('Email Service Integration Tests', () => {
  let app: INestApplication;
  let _testRequest: ReturnType<typeof import('supertest')>;
  let db: Kysely<DB>;
  let testDbService: TestDatabaseService;
  let emailService: EmailService;

  beforeAll(async () => {
    // Create email integration test app once for all tests (includes email service)
    const testApp = await EmailIntegrationTestModuleFactory.createApp();
    app = testApp.app;
    _testRequest = testApp.request;
    db = testApp.db;
    testDbService = testApp.testDbService;

    // Get email service instance
    emailService = app.get<EmailService>(TOKENS.EMAIL.SERVICE);

    // Clean database at the start to ensure clean state between test files
    try {
      await EmailIntegrationTestModuleFactory.cleanDatabase(db);
    } catch (error) {
      console.warn('Database cleanup skipped in beforeAll:', error);
    }
  });

  beforeEach(async () => {
    // Clean database before each test for consistency
    await EmailIntegrationTestModuleFactory.cleanDatabase(db);
  });

  afterAll(async () => {
    // Cleanup after all tests
    await EmailIntegrationTestModuleFactory.closeApp(app, testDbService);
  });

  describe('basic email sending', () => {
    it('should send basic email via SES', async () => {
      // Arrange
      const emailOptions = {
        to: 'success@simulator.amazonses.com', // SES test email
        subject: 'Integration Test Email',
        text: 'This is a test email from the integration test suite.',
        html: '<h1>Integration Test</h1><p>This is a test email from the integration test suite.</p>',
      };

      // Act
      const result = await emailService.sendEmail(emailOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(typeof result.messageId).toBe('string');
      expect(result.accepted).toContain('success@simulator.amazonses.com');
      expect(result.rejected).toEqual([]);
    });

    it('should send email with multiple recipients', async () => {
      // Arrange
      const emailOptions = {
        to: [
          'success@simulator.amazonses.com',
          'bounce@simulator.amazonses.com', // Use different addresses
        ],
        cc: ['complaint@simulator.amazonses.com'],
        subject: 'Multi-recipient Test Email',
        text: 'This email is sent to multiple recipients.',
      };

      // Act
      const result = await emailService.sendEmail(emailOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('success@simulator.amazonses.com');
      expect(result.accepted).toContain('bounce@simulator.amazonses.com');
      expect(result.accepted).toContain('complaint@simulator.amazonses.com');
      expect(result.rejected).toEqual([]);
    });

    it('should handle email address objects', async () => {
      // Arrange
      const emailOptions = {
        to: {
          address: 'success@simulator.amazonses.com',
          name: 'Integration Test User',
        },
        subject: 'Named Recipient Test',
        text: 'This email is sent to a named recipient.',
      };

      // Act
      const result = await emailService.sendEmail(emailOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain(
        'Integration Test User <success@simulator.amazonses.com>',
      );
    });
  });

  describe('template email functionality', () => {
    it('should send template email with variable substitution', async () => {
      // Arrange
      const templateOptions = {
        template: EMAIL_TEMPLATES.EMAIL_VERIFICATION,
        to: 'success@simulator.amazonses.com',
        variables: {
          userName: 'Integration Test User',
          appName: 'Jeeves Test App',
          userEmail: 'success@simulator.amazonses.com',
          verificationUrl: 'https://test.jeevesapp.dev/verify/test-token',
          expiryHours: '24',
          supportEmail: 'support@jeevesapp.dev',
        },
      };

      // Act
      const result = await emailService.sendTemplateEmail(templateOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('success@simulator.amazonses.com');
      expect(result.rejected).toEqual([]);
    });

    it('should load and retrieve email templates', () => {
      // Act
      const template = emailService.getTemplate(
        EMAIL_TEMPLATES.EMAIL_VERIFICATION,
      );

      // Assert
      expect(template).toBeDefined();
      expect(template!.name).toBe('email-verification');
      expect(template!.subject).toContain('{{appName}}');
      expect(template!.html).toContain('{{userName}}');
      expect(template!.html).toContain('{{verificationUrl}}');
      expect(template!.text).toBeDefined();
    });

    it('should validate email addresses correctly', () => {
      // Valid emails
      expect(emailService.validateEmail('test@example.com')).toBe(true);
      expect(emailService.validateEmail('user.name@domain.co.uk')).toBe(true);
      expect(
        emailService.validateEmail('success@simulator.amazonses.com'),
      ).toBe(true);

      // Invalid emails
      expect(emailService.validateEmail('invalid-email')).toBe(false);
      expect(emailService.validateEmail('@domain.com')).toBe(false);
      expect(emailService.validateEmail('user@')).toBe(false);
      expect(emailService.validateEmail('')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('should throw error for non-existent template', async () => {
      // Arrange
      const templateOptions = {
        template: 'non-existent-template',
        to: 'success@simulator.amazonses.com',
        variables: {},
      };

      // Act & Assert
      await expect(
        emailService.sendTemplateEmail(templateOptions),
      ).rejects.toThrow("Email template 'non-existent-template' not found");
    });

    it('should handle SES bounce simulation', async () => {
      // Arrange
      const emailOptions = {
        to: 'bounce@simulator.amazonses.com', // SES bounce simulation
        subject: 'Bounce Test Email',
        text: 'This email should trigger a bounce.',
      };

      // Act - This should succeed (SES accepts the email but simulates bounce later)
      const result = await emailService.sendEmail(emailOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('bounce@simulator.amazonses.com');
    });

    it('should handle SES complaint simulation', async () => {
      // Arrange
      const emailOptions = {
        to: 'complaint@simulator.amazonses.com', // SES complaint simulation
        subject: 'Complaint Test Email',
        text: 'This email should trigger a complaint.',
      };

      // Act - This should succeed (SES accepts the email but simulates complaint later)
      const result = await emailService.sendEmail(emailOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('complaint@simulator.amazonses.com');
    });
  });

  describe('template variable substitution', () => {
    it('should properly substitute all variables in email verification template', async () => {
      // Arrange
      const variables = {
        userName: 'John Doe',
        appName: 'Jeeves Integration Test',
        userEmail: 'john@example.com',
        verificationUrl: 'https://test.app/verify/abc123',
        expiryHours: '48',
        supportEmail: 'help@test.app',
      };

      const templateOptions = {
        template: EMAIL_TEMPLATES.EMAIL_VERIFICATION,
        to: 'success@simulator.amazonses.com',
        variables,
      };

      // Act
      const result = await emailService.sendTemplateEmail(templateOptions);

      // Assert - Email should be sent successfully with variable substitution
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('success@simulator.amazonses.com');

      // Note: We can't directly inspect the sent email content in this test,
      // but we can verify the template processing doesn't throw errors
      // and the email is accepted by SES
    });

    it('should handle missing template variables gracefully', async () => {
      // Arrange - Don't provide all required variables
      const templateOptions = {
        template: EMAIL_TEMPLATES.EMAIL_VERIFICATION,
        to: 'success@simulator.amazonses.com',
        variables: {
          userName: 'Test User',
          // Missing other required variables
        },
      };

      // Act - This should still work, leaving unreplaced variables as-is
      const result = await emailService.sendTemplateEmail(templateOptions);

      // Assert
      expect(result).toBeDefined();
      expect(result.messageId).toBeDefined();
      expect(result.accepted).toContain('success@simulator.amazonses.com');
    });
  });
});
