import type { Insertable, Selectable } from 'kysely';
import type {
  Message,
  TypingIndicator,
  User,
  Household,
  HouseholdMember,
} from '../../generated/database.js';

/**
 * Test fixtures for database entities
 */
export class DatabaseFixtures {
  /**
   * Creates a test user fixture
   */
  static createUser(
    overrides: Partial<Insertable<User>> = {},
  ): Insertable<User> {
    return {
      id: 'test-user-id',
      auth_user_id: 'test-auth-user-id',
      email: 'test@example.com',
      first_name: 'Test',
      last_name: 'User',
      display_name: 'Test User',
      avatar_url: null,
      birth_date: null,
      phone: null,
      preferences: null,
      permissions: null,
      managed_by: null,
      relationship_to_manager: null,
      primary_household_id: null,
      ...overrides,
    };
  }

  /**
   * Creates a test user result (with generated fields)
   */
  static createUserResult(
    overrides: Partial<Selectable<User>> = {},
  ): Selectable<User> {
    const baseUser = this.createUser();
    return {
      id: baseUser.id || 'test-user-id',
      auth_user_id: baseUser.auth_user_id || 'test-auth-user-id',
      email: baseUser.email || 'test@example.com',
      first_name: baseUser.first_name || 'Test',
      last_name: baseUser.last_name || 'User',
      display_name: baseUser.display_name || 'Test User',
      avatar_url: baseUser.avatar_url,
      birth_date:
        baseUser.birth_date instanceof Date
          ? baseUser.birth_date
          : typeof baseUser.birth_date === 'string'
            ? new Date(baseUser.birth_date)
            : baseUser.birth_date,
      phone: baseUser.phone,
      preferences: baseUser.preferences,
      permissions: baseUser.permissions,
      managed_by: baseUser.managed_by,
      relationship_to_manager: baseUser.relationship_to_manager,
      primary_household_id: baseUser.primary_household_id,
      created_at: new Date(),
      updated_at: new Date(),
      is_ai: baseUser.is_ai || false,
      ...overrides,
    };
  }

  /**
   * Creates a test message fixture
   */
  static createMessage(
    overrides: Partial<Insertable<Message>> = {},
  ): Insertable<Message> {
    return {
      id: 'test-message-id',
      household_id: 'test-household-id',
      user_id: 'test-user-id',
      content: 'Test message content',
      message_type: 'text',
      metadata: null,
      ...overrides,
    };
  }

  /**
   * Creates a test message result (with generated fields)
   */
  static createMessageResult(
    overrides: Partial<Selectable<Message>> = {},
  ): Selectable<Message> {
    const baseMessage = this.createMessage();
    return {
      id: baseMessage.id || 'test-message-id',
      household_id: baseMessage.household_id || 'test-household-id',
      user_id: baseMessage.user_id || 'test-user-id',
      content: baseMessage.content || 'Test message content',
      message_type: baseMessage.message_type || 'text',
      metadata: baseMessage.metadata,
      created_at: new Date(),
      updated_at: new Date(),
      ...overrides,
    };
  }

  /**
   * Creates a test typing indicator fixture
   */
  static createTypingIndicator(
    overrides: Partial<Insertable<TypingIndicator>> = {},
  ): Insertable<TypingIndicator> {
    return {
      id: 'test-typing-indicator-id',
      household_id: 'test-household-id',
      user_id: 'test-user-id',
      ...overrides,
    };
  }

  /**
   * Creates a test typing indicator result (with generated fields)
   */
  static createTypingIndicatorResult(
    overrides: Partial<Selectable<TypingIndicator>> = {},
  ): Selectable<TypingIndicator> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 30000); // 30 seconds from now
    const baseIndicator = this.createTypingIndicator();

    return {
      id: baseIndicator.id || 'test-typing-indicator-id',
      household_id: baseIndicator.household_id || 'test-household-id',
      user_id: baseIndicator.user_id || 'test-user-id',
      created_at: now,
      expires_at: expiresAt,
      last_typing_at: now,
      is_typing: true,
      ...overrides,
    };
  }

  /**
   * Creates an AI message fixture
   */
  static createAIMessage(
    overrides: Partial<Insertable<Message>> = {},
  ): Insertable<Message> {
    return this.createMessage({
      user_id: null, // AI messages don't have a user_id
      message_type: 'ai',
      content: 'AI generated response',
      metadata: { ai_model: 'gpt-4', confidence: 0.95 },
      ...overrides,
    });
  }

  /**
   * Creates a system message fixture
   */
  static createSystemMessage(
    overrides: Partial<Insertable<Message>> = {},
  ): Insertable<Message> {
    return this.createMessage({
      user_id: null, // System messages don't have a user_id
      message_type: 'system',
      content: 'System notification',
      ...overrides,
    });
  }

  /**
   * Creates an AI user fixture
   */
  static createAIUser(
    overrides: Partial<Insertable<User>> = {},
  ): Insertable<User> {
    return this.createUser({
      id: 'test-ai-user-id',
      email: 'ai-assistant@system.internal',
      first_name: 'Chat',
      last_name: 'Assistant',
      display_name: 'Chat Assistant',
      avatar_url: '/avatars/default-ai-assistant.png',
      auth_user_id: null, // AI users don't have auth
      is_ai: true, // Explicitly mark as AI user
      ...overrides,
    });
  }

  /**
   * Creates a managed user fixture (user with a manager)
   */
  static createManagedUser(
    managerId: string = 'test-manager-id',
    overrides: Partial<Insertable<User>> = {},
  ): Insertable<User> {
    return this.createUser({
      id: 'test-managed-user-id',
      managed_by: managerId,
      relationship_to_manager: 'child',
      auth_user_id: null, // Managed users don't have direct auth
      email: null,
      ...overrides,
    });
  }

  /**
   * Creates a manager user fixture (user who manages others)
   */
  static createManagerUser(
    overrides: Partial<Insertable<User>> = {},
  ): Insertable<User> {
    return this.createUser({
      id: 'test-manager-user-id',
      email: 'manager@example.com',
      first_name: 'Manager',
      last_name: 'User',
      display_name: 'Manager User',
      ...overrides,
    });
  }

  /**
   * Creates a test household fixture
   */
  static createHousehold(
    overrides: Partial<Insertable<Household>> = {},
  ): Insertable<Household> {
    return {
      id: 'test-household-id',
      name: 'Test Household',
      description: 'A test household',
      created_by: 'test-user-id',
      ...overrides,
    };
  }

  /**
   * Creates a test household result (with generated fields)
   */
  static createHouseholdRecord(
    overrides: Partial<Selectable<Household>> = {},
  ): Selectable<Household> {
    const baseHousehold = this.createHousehold();
    return {
      id: baseHousehold.id || 'test-household-id',
      name: baseHousehold.name || 'Test Household',
      description: baseHousehold.description || 'A test household',
      created_by: baseHousehold.created_by || 'test-user-id',
      created_at: new Date(),
      updated_at: new Date(),
      ...overrides,
    };
  }

  /**
   * Creates a test household member fixture
   */
  static createHouseholdMember(
    overrides: Partial<Insertable<HouseholdMember>> = {},
  ): Insertable<HouseholdMember> {
    return {
      id: 'test-household-member-id',
      household_id: 'test-household-id',
      user_id: 'test-user-id',
      role: 'member',
      ...overrides,
    };
  }

  /**
   * Creates a test household member result (with generated fields)
   */
  static createHouseholdMemberRecord(
    overrides: Partial<Selectable<HouseholdMember>> = {},
  ): Selectable<HouseholdMember> {
    const baseMember = this.createHouseholdMember();
    return {
      id: baseMember.id || 'test-household-member-id',
      household_id: baseMember.household_id || 'test-household-id',
      user_id: baseMember.user_id || 'test-user-id',
      role: baseMember.role || 'member',
      joined_at: new Date(),
      ...overrides,
    };
  }
}
