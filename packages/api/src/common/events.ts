/**
 * Centralized event names for the application
 * Using a constant structure to organize events by domain and prevent typos
 */

export const EVENTS = {
  // User permission related events
  USER: {
    PERMISSIONS: {
      RECOMPUTE: 'user.permissions.recompute',
    },
  },

  // Message related events
  MESSAGE: {
    SAVED: 'message.saved',
  },

  // Household related events
  HOUSEHOLD: {
    MEMBER_ADDED: 'household.member.added',
    MEMBER_REMOVED: 'household.member.removed',
    MEMBER_ROLE_CHANGED: 'household.member.role.changed',
  },
} as const;

// Type helpers for better type safety
export type EventMap = typeof EVENTS;
export type UserEvents = typeof EVENTS.USER;
export type MessageEvents = typeof EVENTS.MESSAGE;
export type HouseholdEvents = typeof EVENTS.HOUSEHOLD;
