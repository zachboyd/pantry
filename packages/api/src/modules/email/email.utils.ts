import type { EmailAddress } from './email.types.js';

/**
 * Normalizes a single email address to a string format
 * @param email - Email address as string or EmailAddress object
 * @returns Normalized email address string
 * @example
 * normalizeEmailAddress('user@example.com') // 'user@example.com'
 * normalizeEmailAddress({ name: 'John Doe', address: 'john@example.com' }) // 'John Doe <john@example.com>'
 */
export function normalizeEmailAddress(email: string | EmailAddress): string {
  if (typeof email === 'string') {
    return email;
  }
  return email.name ? `${email.name} <${email.address}>` : email.address;
}

/**
 * Normalizes email addresses (single or array) to an array of strings
 * @param emails - Email addresses in various formats
 * @returns Array of normalized email address strings
 * @example
 * normalizeEmailAddresses('user@example.com') // ['user@example.com']
 * normalizeEmailAddresses(['user1@example.com', { name: 'User 2', address: 'user2@example.com' }])
 * // ['user1@example.com', 'User 2 <user2@example.com>']
 */
export function normalizeEmailAddresses(
  emails: string | string[] | EmailAddress | EmailAddress[],
): string[] {
  const emailArray = Array.isArray(emails) ? emails : [emails];
  return emailArray.map((email) => normalizeEmailAddress(email));
}
