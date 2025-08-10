import Foundation
import Security

// MARK: - Auth User Data

/// Represents user data stored for offline use
public struct AuthUserData: Codable {
    public let userId: String
    public let email: String
    public let name: String?
    public let image: String?
    public let emailVerified: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        userId: String,
        email: String,
        name: String? = nil,
        image: String? = nil,
        emailVerified: Bool = false,
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.userId = userId
        self.email = email
        self.name = name
        self.image = image
        self.emailVerified = emailVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Initialize from APIUser
    public init(from apiUser: APIUser) {
        userId = apiUser.id
        email = apiUser.email
        name = apiUser.name
        image = apiUser.image
        emailVerified = apiUser.emailVerified
        createdAt = apiUser.createdAt
        updatedAt = apiUser.updatedAt
    }
}

// MARK: - Auth Token

/// Represents an authentication token with metadata
public struct AuthToken {
    public let accessToken: String
    public let refreshToken: String?
    public let userId: LowercaseUUID?
    public let expiresAt: Date?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        userId: LowercaseUUID? = nil,
        expiresAt: Date? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        self.expiresAt = expiresAt
    }

    /// Check if the token is still valid (not expired)
    public var isValid: Bool {
        guard let expiresAt = expiresAt else {
            // If no expiration date, assume valid
            return true
        }
        return Date() < expiresAt
    }

    /// Check if token will expire soon (within 5 minutes)
    public var needsRefresh: Bool {
        guard let expiresAt = expiresAt else {
            return false
        }
        return Date().addingTimeInterval(300) >= expiresAt // 5 minutes
    }
}

// MARK: - AuthTokenManager

/// Manages secure storage and retrieval of authentication tokens
@MainActor
public final class AuthTokenManager {
    private static let logger = Logger(category: "AuthTokenManager")

    private static let service = "com.pantry.app"
    private static let accessTokenKey = "auth_access_token"
    private static let refreshTokenKey = "auth_refresh_token"
    private static let userIdKey = "auth_user_id"
    private static let expirationKey = "auth_expiration"
    private static let userDataKey = "auth_user_data"

    // In-memory cache to avoid repeated keychain reads
    private var cachedToken: AuthToken?
    private var cachedUserData: AuthUserData?

    public init() {
        Self.logger.info("🔐 AuthTokenManager initialized")
        // Load token from keychain on initialization
        cachedToken = loadTokenFromKeychain()
        cachedUserData = try? loadUserDataFromKeychain()
    }

    // MARK: - Public Methods

    /// Save authentication token securely to Keychain
    public func saveToken(_ token: AuthToken) throws {
        Self.logger.debug("💾 Saving auth token")

        // Save access token
        try saveToKeychain(token.accessToken, key: Self.accessTokenKey)

        // Save refresh token if available
        if let refreshToken = token.refreshToken {
            try saveToKeychain(refreshToken, key: Self.refreshTokenKey)
        }

        // Save user ID if available
        if let userId = token.userId {
            try saveToKeychain(userId.uuidString, key: Self.userIdKey)
        }

        // Save expiration date if available
        if let expiresAt = token.expiresAt {
            let timeInterval = expiresAt.timeIntervalSince1970
            try saveToKeychain(String(timeInterval), key: Self.expirationKey)
        }

        // Update in-memory cache
        cachedToken = token
        Self.logger.debug("✅ Auth token saved")
    }

    /// Load authentication token from cache (or Keychain if not cached)
    public func loadToken() -> AuthToken? {
        // Return cached token if available
        if let cached = cachedToken {
            Self.logger.debug("📖 Returning cached auth token (valid: \(cached.isValid))")
            return cached
        }

        // Otherwise load from keychain and cache it
        Self.logger.debug("📖 Cache miss - loading auth token from Keychain")
        let token = loadTokenFromKeychain()
        cachedToken = token
        return token
    }

    /// Load authentication token directly from Keychain (bypasses cache)
    private func loadTokenFromKeychain() -> AuthToken? {
        Self.logger.debug("🔑 Loading auth token from Keychain")

        guard let accessToken = loadFromKeychain(key: Self.accessTokenKey) else {
            Self.logger.debug("🔑 No access token found in Keychain")
            return nil
        }

        let refreshToken = loadFromKeychain(key: Self.refreshTokenKey)

        let userId: LowercaseUUID? = {
            guard let userIdString = loadFromKeychain(key: Self.userIdKey) else {
                return nil
            }
            return LowercaseUUID(uuidString: userIdString)
        }()

        let expiresAt: Date? = {
            guard let expirationString = loadFromKeychain(key: Self.expirationKey),
                  let timeInterval = Double(expirationString)
            else {
                return nil
            }
            return Date(timeIntervalSince1970: timeInterval)
        }()

        let token = AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            expiresAt: expiresAt
        )

        Self.logger.debug("✅ Auth token loaded from Keychain")
        return token
    }

    /// Clear all authentication data from Keychain
    public func clearToken() throws {
        Self.logger.info("🗑️ Clearing auth token from Keychain and cache")

        try deleteFromKeychain(key: Self.accessTokenKey)
        try deleteFromKeychain(key: Self.refreshTokenKey)
        try deleteFromKeychain(key: Self.userIdKey)
        try deleteFromKeychain(key: Self.expirationKey)
        try deleteFromKeychain(key: Self.userDataKey)

        // Clear in-memory cache
        cachedToken = nil
        cachedUserData = nil

        Self.logger.info("✅ Auth token and cache cleared successfully")
    }

    /// Save user data for offline use
    public func saveUserData(_ userData: AuthUserData) throws {
        Self.logger.debug("💾 Saving user data")

        let encoder = JSONEncoder()
        let data = try encoder.encode(userData)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw KeychainError.saveFailure(-1)
        }

        try saveToKeychain(jsonString, key: Self.userDataKey)

        // Update in-memory cache
        cachedUserData = userData
        Self.logger.debug("✅ User data saved")
    }

    /// Load user data from cache (or Keychain if not cached)
    public func loadUserData() throws -> AuthUserData? {
        // Return cached data if available
        if let cached = cachedUserData {
            Self.logger.debug("📖 Returning cached user data")
            return cached
        }

        // Otherwise load from keychain and cache it
        Self.logger.debug("📖 Cache miss - loading user data from Keychain")
        let userData = try loadUserDataFromKeychain()
        cachedUserData = userData
        return userData
    }

    /// Load user data directly from Keychain (bypasses cache)
    private func loadUserDataFromKeychain() throws -> AuthUserData? {
        Self.logger.debug("🔑 Loading user data from Keychain")

        guard let jsonString = loadFromKeychain(key: Self.userDataKey),
              let data = jsonString.data(using: .utf8)
        else {
            Self.logger.debug("🔑 No user data found in Keychain")
            return nil
        }

        let decoder = JSONDecoder()
        let userData = try decoder.decode(AuthUserData.self, from: data)
        Self.logger.debug("✅ User data loaded from Keychain")
        return userData
    }

    /// Check if a valid token exists
    public func hasValidToken() -> Bool {
        guard let token = loadToken() else { return false }
        return token.isValid
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(_ value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AuthError.updateFailed
        }

        // First, delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess {
            throw KeychainError.saveFailure(status)
        }
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8)
        {
            return string
        }

        return nil
    }

    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success or item not found are both acceptable
        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.deleteFailure(status)
        }
    }
}

// MARK: - Keychain Errors

public enum KeychainError: Error, LocalizedError {
    case saveFailure(OSStatus)
    case deleteFailure(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .saveFailure(status):
            return "Failed to save to Keychain: \(status)"
        case let .deleteFailure(status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}

// MARK: - Supporting Types

/// UUID type that ensures lowercase string representation
public struct LowercaseUUID: Codable, Hashable, Sendable {
    public let uuidString: String

    public init?(uuidString: String) {
        guard UUID(uuidString: uuidString) != nil else { return nil }
        self.uuidString = uuidString.lowercased()
    }

    public init() {
        uuidString = UUID().uuidString.lowercased()
    }
}

/// Auth error types
public enum AuthError: Error {
    case updateFailed
}

/// API User type (placeholder - will be replaced with actual API types)
public struct APIUser: Codable {
    public let id: String
    public let email: String
    public let name: String?
    public let image: String?
    public let emailVerified: Bool
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        email: String,
        name: String? = nil,
        image: String? = nil,
        emailVerified: Bool = false,
        createdAt: String = "",
        updatedAt: String = ""
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.image = image
        self.emailVerified = emailVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
