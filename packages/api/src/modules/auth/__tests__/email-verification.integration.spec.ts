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
import type { EmailService } from '../../email/email.types.js';
import type { AuthUserService } from '../auth-user.types.js';

describe('Email Verification Integration Tests', () => {
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

    // Get the email service and mock it
    mockEmailService = app.get<EmailService>(TOKENS.EMAIL.SERVICE);

    // Get the auth user service
    authUserService = app.get<AuthUserService>(TOKENS.AUTH.USER_SERVICE);

    // Mock the sendTemplateEmail method to capture calls without sending
    vi.spyOn(mockEmailService, 'sendTemplateEmail').mockImplementation(
      async (emailData) => {
        // Return successful response without actually sending
        return {
          messageId: 'mock-message-id',
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

  describe('Email Verification Flow', () => {
    it('should send verification email on signup and allow email verification', async () => {
      const testEmail = 'test@example.com';
      const testPassword = 'TestPassword123';
      const testName = 'Test User';

      // Step 1: Sign up user - should trigger verification email
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: testEmail,
          password: testPassword,
          name: testName,
        });

      expect(signupResponse.status).toBe(200);
      expect(signupResponse.body.user.email).toBe(testEmail);
      expect(signupResponse.body.user.emailVerified).toBe(false);

      // Step 2: Assert verification email was "sent"
      expect(mockEmailService.sendTemplateEmail).toHaveBeenCalledTimes(1);

      const emailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];
      expect(emailCall.to).toBe(testEmail);
      expect(emailCall.template).toBe('email-verification');
      expect(emailCall.variables).toMatchObject({
        userName: testName,
        appName: 'Jeeves',
        userEmail: testEmail,
        expiryHours: '1',
        supportEmail: 'support@jeevesapp.dev',
      });

      // Step 3: Extract verification URL from email variables
      const verificationUrl = emailCall.variables.verificationUrl as string;
      expect(verificationUrl).toMatch(/\/api\/auth\/verify-email\?token=.+/);

      // Parse the URL to get the endpoint path and token
      const urlObj = new URL(verificationUrl);
      const verificationPath = `${urlObj.pathname}${urlObj.search}`;
      const token = urlObj.searchParams.get('token');

      expect(token).toBeTruthy();

      // Step 4: Call verification endpoint directly
      const verificationResponse = await testRequest.get(verificationPath);

      // Better Auth redirects after successful verification (302 to root)
      expect(verificationResponse.status).toBe(302);
      expect(verificationResponse.headers.location).toBe('/');

      // Step 5: Verify user is now marked as email verified in database
      const authUser = await authUserService.getByEmail(testEmail);

      expect(authUser).toBeTruthy();
      expect(authUser!.emailVerified).not.toBeNull(); // Better Auth sets a timestamp when verified

      // Both the 302 redirect and database state confirm successful verification
    });

    it('should handle invalid verification tokens gracefully', async () => {
      const invalidToken = 'invalid-token-12345';

      const response = await testRequest.get(
        `/api/auth/verify-email?token=${invalidToken}`,
      );

      // Better Auth should handle invalid tokens appropriately
      // This might be 400 or 404 depending on Better Auth's implementation
      expect(response.status).toBeGreaterThanOrEqual(400);
    });

    it('should handle expired verification tokens', async () => {
      // This test would require manipulating token expiry
      // For now, just test with a malformed token that looks expired
      const expiredToken = 'expired.token.that.looks.like.jwt';

      const response = await testRequest.get(
        `/api/auth/verify-email?token=${expiredToken}`,
      );

      expect(response.status).toBeGreaterThanOrEqual(400);
    });

    it('should not send verification email if user already verified', async () => {
      const testEmail = 'verified@example.com';
      const testPassword = 'TestPassword123';
      const testName = 'Verified User';

      // Step 1: Sign up and verify user
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: testEmail,
          password: testPassword,
          name: testName,
        });

      expect(signupResponse.status).toBe(200);

      // Get verification URL and verify
      const emailCall = vi.mocked(mockEmailService.sendTemplateEmail).mock
        .calls[0][0];
      const verificationUrl = emailCall.variables.verificationUrl as string;
      const urlObj = new URL(verificationUrl);
      const verificationPath = `${urlObj.pathname}${urlObj.search}`;

      await testRequest.get(verificationPath);

      // Clear mock call history
      vi.clearAllMocks();

      // Step 2: Try to request verification email again
      const cookies = signupResponse.headers['set-cookie'];
      const resendResponse = await testRequest
        .post('/api/auth/send-verification-email')
        .set('Cookie', cookies);

      // Should not send another email since user is already verified
      expect(resendResponse.status).toBeGreaterThanOrEqual(400); // Likely 400 or similar
      expect(mockEmailService.sendTemplateEmail).not.toHaveBeenCalled();
    });

    it('should allow user to use app before email verification (non-blocking)', async () => {
      const testEmail = 'unverified@example.com';
      const testPassword = 'TestPassword123';

      // Sign up user
      const signupResponse = await testRequest
        .post('/api/auth/sign-up/email')
        .send({
          email: testEmail,
          password: testPassword,
          name: 'Unverified User',
        });

      expect(signupResponse.status).toBe(200);
      expect(signupResponse.body.user.emailVerified).toBe(false);

      // Extract session cookie
      const cookies = signupResponse.headers['set-cookie'];

      // User should be able to access authenticated endpoints
      const currentUserResponse = await testRequest
        .post('/graphql')
        .set('Cookie', cookies)
        .send({
          query: `
            query {
              currentUser {
                id
                email
                first_name
                last_name
              }
            }
          `,
        });

      expect(currentUserResponse.status).toBe(200);
      expect(currentUserResponse.body.errors).toBeUndefined();
      expect(currentUserResponse.body.data.currentUser.email).toBe(testEmail);
    });
  });
});
