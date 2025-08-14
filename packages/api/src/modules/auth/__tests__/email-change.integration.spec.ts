import {
  afterAll,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest';
import type { INestApplication } from '@nestjs/common';
import type { Kysely } from 'kysely';
import type { DB } from '../../../generated/database.js';
import { EmailIntegrationTestModuleFactory } from '../../../test/utils/email-integration-test-module-factory.js';
import { TOKENS } from '../../../common/tokens.js';
import type { EmailService, EmailAddress } from '../../email/email.types.js';
import type { AuthUserService } from '../auth-user.types.js';

describe('Email Change Integration Tests', () => {
  let app: INestApplication;
  let db: Kysely<DB>;
  let mockEmailService: EmailService;
  let authUserService: AuthUserService;
  let testRequest: ReturnType<typeof import('supertest')>;

  beforeAll(async () => {
    // Create app with email integration enabled (includes email service)
    const testSetup = await EmailIntegrationTestModuleFactory.createApp();
    app = testSetup.app;
    db = testSetup.db;
    testRequest = testSetup.request;

    // Get services
    mockEmailService = app.get<EmailService>(TOKENS.EMAIL.SERVICE);
    authUserService = app.get<AuthUserService>(TOKENS.AUTH.USER_SERVICE);

    // Track all email calls with detailed logging
    let emailCallCount = 0;
    const allEmailCalls: Array<{
      callNumber: number;
      to: string | string[] | EmailAddress | EmailAddress[];
      template: string;
      variables: Record<string, unknown>;
      timestamp: string;
    }> = [];

    // Mock the sendTemplateEmail method to capture calls without sending
    vi.spyOn(mockEmailService, 'sendTemplateEmail').mockImplementation(
      async (emailData) => {
        emailCallCount++;
        allEmailCalls.push({
          callNumber: emailCallCount,
          to: emailData.to,
          template: emailData.template,
          variables: emailData.variables,
          timestamp: new Date().toISOString(),
        });

        // Return successful response without actually sending
        return {
          messageId: `mock-message-id-${emailCallCount}`,
          accepted: [
            typeof emailData.to === 'string'
              ? emailData.to
              : emailData.to.toString(),
          ],
          rejected: [],
        };
      },
    );
  });

  afterAll(async () => {
    await EmailIntegrationTestModuleFactory.closeApp(app);
  });

  beforeEach(async () => {
    // Clean database before each test
    await EmailIntegrationTestModuleFactory.cleanDatabase(db);

    // Clear mock call history
    vi.clearAllMocks();
  });

  describe('Email Change Flow', () => {
    it('should handle email change with secure verification', async () => {
      const currentEmail = 'current@example.com';
      const newEmail = 'new@example.com';
      const testPassword = 'TestPassword123';
      const testName = 'Test User';

      // Step 1: Sign up user with current email
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: currentEmail,
          password: testPassword,
          name: testName,
        });

      expect(signupResponse.status).toBe(200);
      expect(signupResponse.body.user.email).toBe(currentEmail);

      // Step 2: Verify the current email first

      // Get the verification email that was sent during signup
      expect(mockEmailService.sendTemplateEmail).toHaveBeenCalledTimes(1);
      const signupEmailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];
      const firstVerificationUrl = signupEmailCall.variables
        .verificationUrl as string;

      // Parse the URL to get the verification endpoint
      const firstUrlObj = new URL(firstVerificationUrl);
      const firstVerificationPath = `${firstUrlObj.pathname}${firstUrlObj.search}`;

      // Complete email verification
      const verificationResponse = await testRequest.get(firstVerificationPath);
      expect(verificationResponse.status).toBe(302); // Redirect after verification

      // Verify the user's email is now verified
      const user = await authUserService.getByEmail(currentEmail);

      expect(user?.emailVerified).toBe(true);

      // Clear signup and verification email mock calls
      vi.clearAllMocks();

      // Step 3: Login again to get fresh session with updated emailVerified status
      const loginResponse = await testRequest
        .post('/api/auth/sign-in/email')
        .send({
          email: currentEmail,
          password: testPassword,
        });

      expect(loginResponse.status).toBe(200);
      expect(loginResponse.body.user.email).toBe(currentEmail);
      expect(loginResponse.body.user.emailVerified).toBe(true);

      // Step 4: Request email change with fresh session
      const freshSessionCookie = loginResponse.headers['set-cookie'];
      const changeEmailResponse = await testRequest
        .post('/api/auth/change-email')
        .set('Cookie', freshSessionCookie)
        .send({
          newEmail: newEmail,
          callbackURL: '/dashboard',
        });

      // Step 5: Assert email change request was processed
      expect(changeEmailResponse.status).toBe(200);

      // Step 6: Verify email change verification was sent correctly
      expect(mockEmailService.sendTemplateEmail).toHaveBeenCalledTimes(1);

      const emailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];

      // Email change verification should be sent to current email for security
      expect(emailCall.to).toBe(currentEmail);
      expect(emailCall.template).toBe('email-change-verification');
      expect(emailCall.variables).toMatchObject({
        userName: testName,
        appName: 'Jeeves',
        currentEmail: currentEmail,
        newEmail: newEmail,
        verificationUrl: expect.any(String),
        expiryHours: '1',
        supportEmail: 'support@jeevesapp.dev',
      });

      // Step 7: Verify verification URL is present
      const changeEmailVerificationUrl = emailCall.variables
        .verificationUrl as string;
      expect(changeEmailVerificationUrl).toMatch(/\/api\/auth\/.+\?token=.+/);
    });

    it('should sync email change to business user record after verification', async () => {
      const currentEmail = 'sync@example.com';
      const newEmail = 'synced@example.com';
      const testPassword = 'TestPassword123';
      const testName = 'Sync Test';

      // Step 1: Sign up user
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: currentEmail,
          password: testPassword,
          name: testName,
        });

      expect(signupResponse.status).toBe(200);
      const authUserId = signupResponse.body.user.id;

      // Step 2: Verify business user was created with current email
      const businessUserBefore = await db
        .selectFrom('user')
        .selectAll()
        .where('auth_user_id', '=', authUserId)
        .executeTakeFirst();

      expect(businessUserBefore).toBeTruthy();
      expect(businessUserBefore!.email).toBe(currentEmail);

      // Step 3: Verify the current email first (required for email change verification)
      // Get the verification email that was sent during signup
      expect(mockEmailService.sendTemplateEmail).toHaveBeenCalledTimes(1);
      const signupEmailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];
      const signupVerificationUrl = signupEmailCall.variables
        .verificationUrl as string;

      // Parse the URL to get the verification endpoint
      const signupUrlObj = new URL(signupVerificationUrl);
      const signupVerificationPath = `${signupUrlObj.pathname}${signupUrlObj.search}`;

      // Complete email verification
      const signupVerificationResponse = await testRequest.get(
        signupVerificationPath,
      );
      expect(signupVerificationResponse.status).toBe(302); // Redirect after verification

      // Clear signup and verification email mock calls
      vi.clearAllMocks();

      // Step 4: Login again to get fresh session with updated emailVerified status
      const loginResponse = await testRequest
        .post('/api/auth/sign-in/email')
        .send({
          email: currentEmail,
          password: testPassword,
        });

      expect(loginResponse.status).toBe(200);
      expect(loginResponse.body.user.emailVerified).toBe(true);

      // Step 5: Request email change with fresh session
      const freshSessionCookie = loginResponse.headers['set-cookie'];
      const changeEmailResponse = await testRequest
        .post('/api/auth/change-email')
        .set('Cookie', freshSessionCookie)
        .send({
          newEmail: newEmail,
        });

      expect(changeEmailResponse.status).toBe(200);

      // Step 6: Extract verification URL from email
      const emailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];
      const changeVerificationUrl = emailCall.variables
        .verificationUrl as string;

      // Parse the URL to get the endpoint path and token
      const changeUrlObj = new URL(changeVerificationUrl);
      const changeVerificationPath = `${changeUrlObj.pathname}${changeUrlObj.search}`;

      // Step 7: Complete email change verification with authenticated session
      const changeVerificationResponse = await testRequest
        .get(changeVerificationPath)
        .set('Cookie', freshSessionCookie);

      // Should redirect after successful verification
      expect(changeVerificationResponse.status).toBe(302);

      // Step 8: Verify auth user email was updated
      const authUser = await authUserService.getByEmail(newEmail);
      expect(authUser).toBeTruthy();
      expect(authUser!.email).toBe(newEmail);

      // Step 9: Verify business user email was synchronized
      const businessUserAfter = await db
        .selectFrom('user')
        .selectAll()
        .where('auth_user_id', '=', authUserId)
        .executeTakeFirst();

      expect(businessUserAfter).toBeTruthy();
      expect(businessUserAfter!.email).toBe(newEmail); // Should be updated via database hook
      expect(businessUserAfter!.display_name).toBe('Sync Test'); // Name should also be synced
      expect(businessUserAfter!.updated_at).not.toEqual(
        businessUserBefore!.updated_at,
      );
    });

    it('should handle email change request for non-authenticated user', async () => {
      const newEmail = 'unauthorized@example.com';

      const changeEmailResponse = await testRequest
        .post('/api/auth/change-email')
        .send({
          newEmail: newEmail,
        });

      // Should require authentication
      expect(changeEmailResponse.status).toBe(401);
      expect(mockEmailService.sendTemplateEmail).not.toHaveBeenCalled();
    });

    it('should validate email format in change email request', async () => {
      const currentEmail = 'valid@example.com';
      const invalidNewEmail = 'not-an-email';
      const testPassword = 'TestPassword123';

      // Step 1: Sign up user
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: currentEmail,
          password: testPassword,
          name: 'Validation Test',
        });

      expect(signupResponse.status).toBe(200);

      // Clear signup email mock calls
      vi.clearAllMocks();

      // Step 2: Request email change with invalid email
      const sessionCookie = signupResponse.headers['set-cookie'];
      const changeEmailResponse = await testRequest
        .post('/api/auth/change-email')
        .set('Cookie', sessionCookie)
        .send({
          newEmail: invalidNewEmail,
        });

      // Should reject invalid email
      expect(changeEmailResponse.status).toBeGreaterThanOrEqual(400);
      expect(mockEmailService.sendTemplateEmail).not.toHaveBeenCalled();
    });
  });
});
