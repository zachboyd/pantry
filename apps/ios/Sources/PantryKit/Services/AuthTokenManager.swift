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

    public init() {
        Self.logger.info("🔐 AuthTokenManager initialized")
    }

    // MARK: - Public Methods

    /// Save authentication token securely to Keychain
    public func saveToken(_ token: AuthToken) throws {
        Self.logger.info("💾 KEYCHAIN SAVE: Saving auth token to Keychain")

        // Save access token
        let accessTokenPreview = String(token.accessToken.prefix(20)) + "..."
        Self.logger.info("💾 KEYCHAIN SAVE: Access Token: \(accessTokenPreview)")
        try saveToKeychain(token.accessToken, key: Self.accessTokenKey)

        // Save refresh token if available
        if let refreshToken = token.refreshToken {
            let refreshTokenPreview = String(refreshToken.prefix(20)) + "..."
            Self.logger.info("💾 KEYCHAIN SAVE: Refresh Token: \(refreshTokenPreview)")
            try saveToKeychain(refreshToken, key: Self.refreshTokenKey)
        } else {
            Self.logger.info("💾 KEYCHAIN SAVE: No refresh token provided")
        }

        // Save user ID if available
        if let userId = token.userId {
            Self.logger.info("💾 KEYCHAIN SAVE: User ID: \(userId.uuidString)")
            try saveToKeychain(userId.uuidString, key: Self.userIdKey)
        } else {
            Self.logger.info("💾 KEYCHAIN SAVE: No user ID provided")
        }

        // Save expiration date if available
        if let expiresAt = token.expiresAt {
            let timeInterval = expiresAt.timeIntervalSince1970
            Self.logger.info("💾 KEYCHAIN SAVE: Expires At: \(expiresAt.description)")
            try saveToKeychain(String(timeInterval), key: Self.expirationKey)
        } else {
            Self.logger.info("💾 KEYCHAIN SAVE: No expiration date provided")
        }

        Self.logger.info("✅ KEYCHAIN SAVE: Auth token saved successfully")
    }

    /// Load authentication token from Keychain
    public func loadToken() -> AuthToken? {
        Self.logger.info("📖 KEYCHAIN LOAD: Loading auth token from Keychain")

        guard let accessToken = loadFromKeychain(key: Self.accessTokenKey) else {
            Self.logger.info("📖 KEYCHAIN LOAD: No access token found in Keychain")
            return nil
        }

        let accessTokenPreview = String(accessToken.prefix(20)) + "..."
        Self.logger.info("📖 KEYCHAIN LOAD: Access Token: \(accessTokenPreview)")

        let refreshToken = loadFromKeychain(key: Self.refreshTokenKey)
        if let refreshToken = refreshToken {
            let refreshTokenPreview = String(refreshToken.prefix(20)) + "..."
            Self.logger.info("📖 KEYCHAIN LOAD: Refresh Token: \(refreshTokenPreview)")
        } else {
            Self.logger.info("📖 KEYCHAIN LOAD: No refresh token found in Keychain")
        }

        let userId: LowercaseUUID? = {
            guard let userIdString = loadFromKeychain(key: Self.userIdKey) else {
                Self.logger.info("📖 KEYCHAIN LOAD: No user ID found in Keychain")
                return nil
            }
            Self.logger.info("📖 KEYCHAIN LOAD: User ID: \(userIdString)")
            return LowercaseUUID(uuidString: userIdString)
        }()

        let expiresAt: Date? = {
            guard let expirationString = loadFromKeychain(key: Self.expirationKey),
                  let timeInterval = Double(expirationString)
            else {
                Self.logger.info("📖 KEYCHAIN LOAD: No expiration date found in Keychain")
                return nil
            }
            let expirationDate = Date(timeIntervalSince1970: timeInterval)
            Self.logger.info("📖 KEYCHAIN LOAD: Expires At: \(expirationDate.description)")
            return expirationDate
        }()

        let token = AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            expiresAt: expiresAt
        )

        Self.logger.info("✅ KEYCHAIN LOAD: Auth token loaded successfully (valid: \(token.isValid), needs refresh: \(token.needsRefresh))")
        return token
    }

    /// Clear all authentication data from Keychain
    public func clearToken() throws {
        Self.logger.info("🗑️ Clearing auth token from Keychain")

        try deleteFromKeychain(key: Self.accessTokenKey)
        try deleteFromKeychain(key: Self.refreshTokenKey)
        try deleteFromKeychain(key: Self.userIdKey)
        try deleteFromKeychain(key: Self.expirationKey)
        try deleteFromKeychain(key: Self.userDataKey)

        Self.logger.info("✅ Auth token cleared successfully")
    }

    /// Save user data for offline use
    public func saveUserData(_ userData: AuthUserData) throws {
        Self.logger.info("💾 Saving user data for offline use")

        let encoder = JSONEncoder()
        let data = try encoder.encode(userData)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw KeychainError.saveFailure(-1)
        }

        try saveToKeychain(jsonString, key: Self.userDataKey)
        Self.logger.info("✅ User data saved successfully")
    }

    /// Load user data from Keychain
    public func loadUserData() throws -> AuthUserData? {
        Self.logger.info("📖 Loading user data from Keychain")

        guard let jsonString = loadFromKeychain(key: Self.userDataKey),
              let data = jsonString.data(using: .utf8)
        else {
            Self.logger.info("📖 No user data found in Keychain")
            return nil
        }

        let decoder = JSONDecoder()
        let userData = try decoder.decode(AuthUserData.self, from: data)
        Self.logger.info("✅ User data loaded successfully: \(userData.email)")
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
