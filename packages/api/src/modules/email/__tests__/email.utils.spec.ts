import { describe, it, expect } from 'vitest';
import {
  normalizeEmailAddress,
  normalizeEmailAddresses,
} from '../email.utils.js';
import type { EmailAddress } from '../email.types.js';

describe('email.utils', () => {
  describe('normalizeEmailAddress', () => {
    it('should return string email address unchanged', () => {
      const email = 'user@example.com';
      const result = normalizeEmailAddress(email);
      expect(result).toBe('user@example.com');
    });

    it('should format EmailAddress object with name', () => {
      const email: EmailAddress = {
        name: 'John Doe',
        address: 'john@example.com',
      };
      const result = normalizeEmailAddress(email);
      expect(result).toBe('John Doe <john@example.com>');
    });

    it('should format EmailAddress object without name', () => {
      const email: EmailAddress = {
        address: 'jane@example.com',
      };
      const result = normalizeEmailAddress(email);
      expect(result).toBe('jane@example.com');
    });

    it('should handle empty name', () => {
      const email: EmailAddress = {
        name: '',
        address: 'test@example.com',
      };
      const result = normalizeEmailAddress(email);
      expect(result).toBe('test@example.com');
    });
  });

  describe('normalizeEmailAddresses', () => {
    it('should handle single string email', () => {
      const result = normalizeEmailAddresses('user@example.com');
      expect(result).toEqual(['user@example.com']);
    });

    it('should handle array of string emails', () => {
      const emails = ['user1@example.com', 'user2@example.com'];
      const result = normalizeEmailAddresses(emails);
      expect(result).toEqual(['user1@example.com', 'user2@example.com']);
    });

    it('should handle single EmailAddress object', () => {
      const email: EmailAddress = {
        name: 'John Doe',
        address: 'john@example.com',
      };
      const result = normalizeEmailAddresses(email);
      expect(result).toEqual(['John Doe <john@example.com>']);
    });

    it('should handle array of EmailAddress objects', () => {
      const emails: EmailAddress[] = [
        { name: 'John Doe', address: 'john@example.com' },
        { address: 'jane@example.com' },
      ];
      const result = normalizeEmailAddresses(emails);
      expect(result).toEqual([
        'John Doe <john@example.com>',
        'jane@example.com',
      ]);
    });

    it('should handle mixed array of strings and EmailAddress objects', () => {
      const stringEmails = ['user1@example.com', 'user2@example.com'];
      const emailObjects: EmailAddress[] = [
        { name: 'John Doe', address: 'john@example.com' },
        { address: 'jane@example.com' },
      ];

      // Test with string array
      const stringResult = normalizeEmailAddresses(stringEmails);
      expect(stringResult).toEqual(['user1@example.com', 'user2@example.com']);

      // Test with EmailAddress array
      const objectResult = normalizeEmailAddresses(emailObjects);
      expect(objectResult).toEqual([
        'John Doe <john@example.com>',
        'jane@example.com',
      ]);
    });

    it('should handle empty array', () => {
      const result = normalizeEmailAddresses([]);
      expect(result).toEqual([]);
    });

    it('should handle complex email address formats', () => {
      const complexEmailObjects: EmailAddress[] = [
        { name: 'User With Spaces', address: 'user.spaces@example.com' },
        { name: 'User+Tag', address: 'user+tag@example.co.uk' },
      ];
      const complexStringEmails = ['simple@domain.org'];

      const objectResult = normalizeEmailAddresses(complexEmailObjects);
      expect(objectResult).toEqual([
        'User With Spaces <user.spaces@example.com>',
        'User+Tag <user+tag@example.co.uk>',
      ]);

      const stringResult = normalizeEmailAddresses(complexStringEmails);
      expect(stringResult).toEqual(['simple@domain.org']);
    });
  });
});
