import Apollo
import CASLSwift
import Combine
import Foundation

/// Protocol defining authentication service interface
@MainActor
public protocol AuthServiceProtocol: AnyObject, Sendable {
    var currentAuthUser: APIUser? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var lastError: String? { get }
    var currentUser: User? { get }
    var currentAbility: JeevesAbility? { get }
    var tokenManager: AuthTokenManager { get }
    var permissionService: PermissionServiceProtocol { get }

    func signIn(email: String, password: String) async throws -> String
    func signUp(email: String, password: String) async throws -> String
    func signOut() async throws
    func validateCurrentSession() async throws -> Bool
    func validateSession() async -> Bool
    func clearStoredSession() async
    func waitForSessionRestoration() async
    func loadUserPermissions() async
}

/// Auth service implementation
/// Handles user authentication, session management with Better-Auth integration
@MainActor
@Observable
public class AuthService: AuthServiceProtocol {
    private static let logger = Logger.auth

    // MARK: - Properties

    private let apiClient: AuthClientProtocol
    private let authTokenManager: AuthTokenManager
    private let _permissionService: PermissionServiceProtocol
    private let apolloClient: ApolloClient?

    // Published state for SwiftUI integration
    public var currentAuthUser: APIUser?
    public var isAuthenticated = false
    public var isLoading = false
    public var lastError: String?
    public var currentAbility: JeevesAbility? {
        _permissionService.currentAbility
    }

    public var currentAuthUserId: String? {
        return currentAuthUser?.id
    }

    /// Expose authTokenManager for other services that need it (e.g., ApolloClientService)
    public var tokenManager: AuthTokenManager {
        return authTokenManager
    }

    /// Expose permissionService for creating PermissionProvider
    public var permissionService: PermissionServiceProtocol {
        return _permissionService
    }

    // Session validation (simplified)
    private var sessionValidationTimer: Timer?
    private let sessionValidationInterval: TimeInterval = 30 * 60 // 30 minutes

    // Session restoration
    private var sessionRestorationTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(apiClient: AuthClientProtocol, authTokenManager: AuthTokenManager, apolloClient: ApolloClient? = nil, permissionService: PermissionServiceProtocol? = nil) {
        self.apiClient = apiClient
        self.authTokenManager = authTokenManager
        self.apolloClient = apolloClient
        _permissionService = permissionService ?? PermissionService()

        Self.logger.info("🔐 AuthService initializing...")

        // Check for existing session synchronously first
        if let storedToken = authTokenManager.loadToken() {
            Self.logger.info("🔐 Found stored auth token in keychain during init")

            // Try to load user data
            if let userData = try? authTokenManager.loadUserData() {
                Self.logger.info("🔐 Found stored user data - setting authenticated state")

                // Restore user state immediately
                currentAuthUser = APIUser(
                    id: userData.userId,
                    email: userData.email,
                    name: userData.name,
                    image: userData.image,
                    emailVerified: userData.emailVerified,
                    createdAt: userData.createdAt,
                    updatedAt: userData.updatedAt
                )
                isAuthenticated = true

                // Set the token in API client
                apiClient.setBetterAuthSessionToken(storedToken.accessToken)

                Self.logger.info("✅ Session restored from keychain for user: \(userData.email)")
            }
        }

        // Then validate the session asynchronously with the server
        // TODO: Fix session validation - currently it's using cookie-based validation
        // but we're using token-based auth. Need to implement proper token validation.
        /*
         Task {
             // Add a small delay to avoid immediate validation issues
             try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

             Self.logger.info("🔐 Starting async session validation...")
             await validateStoredSession()
             Self.logger.info("🔐 Async session validation complete")
         }
         */

        Self.logger.info("🔐 AuthService initialized (authenticated: \(isAuthenticated))")
    }

    // MARK: - AuthServiceProtocol Compatibility

    public var currentUser: User? {
        guard let apiUser = currentAuthUser else { return nil }
        return User(
            id: apiUser.id,
            email: apiUser.email,
            name: apiUser.name,
            createdAt: DateUtilities.dateFromGraphQLOrNow(apiUser.createdAt)
        )
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    public func signIn(email: String, password: String) async throws -> String {
        Self.logger.info("🔐 Signing in user")
        Self.logger.info("🔐 Starting HTTP sign in")

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            Self.logger.info("📡 Making HTTP request to API")
            let response = try await apiClient.signIn(email: email, password: password)
            Self.logger.info("✅ HTTP response received")

            // LOG THE RAW BETTER-AUTH RESPONSE
            Self.logger.debug("🎯 RAW SIGN-IN RESPONSE:")
            Self.logger.debug("🎯 User ID: \(response.user.id)")
            Self.logger.debug("🎯 User Name: \(response.user.name ?? "nil")")
            Self.logger.debug("🎯 User Image: \(response.user.image ?? "nil")")
            Self.logger.debug("🎯 User Created At: \(response.user.createdAt)")
            Self.logger.debug("🎯 User Updated At: \(response.user.updatedAt)")
            Self.logger.debug("🎯 User Email Verified: \(response.user.emailVerified)")
            Self.logger.debug("🎯 Token Length: \(response.token.count)")
            Self.logger.debug("🎯 Token Preview: \(response.token.prefix(50))...")

            Self.logger.info("🎯 [BETTER-AUTH iOS] FULL RESPONSE - User: \(response.user.id), Token: \(response.token.count) chars")

            // Save authentication token to Keychain if provided
            // Note: Better Auth provides a token in the response, but the main authentication
            // relies on HTTP session cookies. We'll store what's available for logging purposes.
            if !response.token.isEmpty {
                do {
                    let authToken = AuthToken(
                        accessToken: response.token,
                        refreshToken: nil, // Better Auth doesn't provide separate refresh token
                        userId: LowercaseUUID(uuidString: response.user.id),
                        expiresAt: nil // Better Auth doesn't provide expiration in sign-in response
                    )
                    try authTokenManager.saveToken(authToken)
                    Self.logger.info("💾 Successfully saved Better Auth session token to Keychain for persistence")

                    // CRITICAL FIX: Set the token in API client for session restoration
                    apiClient.setBetterAuthSessionToken(response.token)
                } catch {
                    Self.logger.warning("⚠️ Failed to save token to Keychain: \(error)")
                    // Continue with authentication even if token save fails
                }
            } else {
                Self.logger.info("💾 No token provided in sign-in response to save")
            }

            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
                isLoading = false
            }

            // Store user data for offline use
            do {
                try authTokenManager.saveUserData(AuthUserData(from: response.user))
                Self.logger.info("💾 Successfully saved user data for offline use")
            } catch {
                Self.logger.warning("⚠️ Failed to save user data: \(error)")
                // Continue - this is not critical for sign in
            }

            // Start session validation
            startSessionValidation()

            Self.logger.info("✅ Sign in successful for user: \(response.user.id)")
            return response.user.id

        } catch {
            await MainActor.run {
                // Use generic error message to avoid revealing if user exists
                lastError = L("auth.error.invalid_credentials")
                isLoading = false
                isAuthenticated = false
                currentAuthUser = nil
            }

            Self.logger.error("❌ Sign in failed: \(error)")
            // Always throw invalidCredentials to avoid revealing information
            throw AuthServiceError.invalidCredentials
        }
    }

    /// Sign up with user details
    public func signUp(email: String, password: String) async throws -> String {
        Self.logger.info("📝 Signing up user")

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            Self.logger.info("📡 Making HTTP request to sign-up endpoint")
            let response = try await apiClient.signUp(email: email, password: password, name: nil)
            Self.logger.info("✅ HTTP sign-up response received")

            // Store token in token manager
            let authToken = AuthToken(
                accessToken: response.token,
                refreshToken: nil,
                userId: LowercaseUUID(uuidString: response.user.id),
                expiresAt: nil
            )
            try authTokenManager.saveToken(authToken)

            // Update auth state
            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
                isLoading = false
                lastError = nil
            }

            // Save user data for offline use
            do {
                try authTokenManager.saveUserData(AuthUserData(from: response.user))
                Self.logger.info("💾 Successfully saved user data for offline use")
            } catch {
                Self.logger.warning("⚠️ Failed to save user data: \(error)")
                // Continue - this is not critical for sign up
            }

            // Start session validation
            startSessionValidation()

            Self.logger.info("✅ Sign up successful for user: \(email)")
            Self.logger.debug("🎯 User ID: \(response.user.id)")

            return response.user.id

        } catch let error as AuthClientError {
            await MainActor.run {
                switch error {
                case let .unknownError(message) where message.contains("already exists"):
                    lastError = L("auth.error.email_exists")
                default:
                    lastError = L("auth.error.general")
                }
                isLoading = false
            }

            Self.logger.error("❌ Sign up failed: \(error)")
            throw AuthServiceError.signUpFailed(error)
        } catch {
            await MainActor.run {
                lastError = L("auth.error.general")
                isLoading = false
            }

            Self.logger.error("❌ Sign up failed: \(error)")
            throw AuthServiceError.signUpFailed(error)
        }
    }

    /// Sign out current user
    public func signOut() async throws {
        Self.logger.info("🔐 Signing out current user")

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            try await apiClient.signOut()

            // Clear tokens from Keychain
            do {
                try authTokenManager.clearToken()
                Self.logger.info("🗑️ Successfully cleared auth tokens from Keychain")
            } catch {
                Self.logger.warning("⚠️ Failed to clear tokens from Keychain: \(error)")
                // Continue with sign out even if token clear fails
            }

            await MainActor.run {
                currentAuthUser = nil
                isAuthenticated = false
                isLoading = false
            }

            // Clear permissions
            await _permissionService.clearPermissions()

            // Stop session validation
            stopSessionValidation()

            Self.logger.info("✅ Sign out successful")

        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false

                // Clear local state anyway
                currentAuthUser = nil
                isAuthenticated = false
            }

            stopSessionValidation()

            Self.logger.error("❌ Sign out failed: \(error)")
            throw AuthServiceError.signOutFailed(error)
        }
    }

    /// Load user permissions from backend
    public func loadUserPermissions() async {
        Self.logger.info("🔐 Loading user permissions")

        // Connect permission service to Apollo for automatic updates
        if let apolloClient = apolloClient {
            await _permissionService.subscribeToUserPermissions(apolloClient: apolloClient)
            Self.logger.info("✅ Permission service connected to Apollo cache")
            Self.logger.info("  - Current ability after subscription: \(_permissionService.currentAbility != nil ? "SET" : "NIL")")
        } else {
            Self.logger.warning("⚠️ No Apollo client available for permission updates")
        }
    }

    /// Clear stored session (used when session is invalid)
    public func clearStoredSession() async {
        Self.logger.info("🗑️ Clearing stored session due to validation failure")

        // Clear tokens from Keychain
        do {
            try authTokenManager.clearToken()
            Self.logger.info("🗑️ Cleared auth token from Keychain")
        } catch {
            Self.logger.warning("⚠️ Failed to clear auth token: \(error)")
        }

        // Clear API client state
        apiClient.clearAuthenticationState()

        // Clear permissions
        await permissionService.clearPermissions()

        // Clear local state
        await MainActor.run {
            currentAuthUser = nil
            isAuthenticated = false
            lastError = nil
        }

        // Stop session validation
        stopSessionValidation()

        Self.logger.info("✅ Stored session cleared")
    }

    /// Validate current session
    public func validateCurrentSession() async throws -> Bool {
        Self.logger.debug("📋 Getting current session")

        do {
            let response = try await apiClient.getSession()

            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
            }

            // Store/update the session token if provided
            if !response.token.isEmpty {
                Self.logger.debug("🔐 Storing/updating Better Auth session token from session validation")

                let authToken = AuthToken(
                    accessToken: response.token,
                    refreshToken: nil,
                    userId: LowercaseUUID(uuidString: response.user.id),
                    expiresAt: nil
                )

                do {
                    try authTokenManager.saveToken(authToken)
                    Self.logger.debug("💾 Updated stored token from session validation")
                } catch {
                    Self.logger.warning("⚠️ Failed to update stored token: \(error)")
                }
            }

            Self.logger.info("✅ Session validated for user: \(response.user.email)")
            return true

        } catch {
            Self.logger.warning("⚠️ Session validation failed: \(error)")
            throw error
        }
    }

    // MARK: - Session Management

    /// Validate current session (simplified)
    public func validateSession() async -> Bool {
        guard isAuthenticated else { return false }

        do {
            return try await validateCurrentSession()
        } catch {
            Self.logger.warning("⚠️ Session validation failed: \(error)")

            // Simple recovery: try to restore from API client cache
            if let cachedUser = apiClient.getAuthUser() {
                Self.logger.info("🔄 Restoring user from API client cache: \(cachedUser.email)")
                await MainActor.run {
                    currentAuthUser = cachedUser
                    isAuthenticated = true
                }
                Self.logger.info("✅ Successfully restored auth state from cache")
                return true
            } else {
                Self.logger.warning("❌ Session validation failed and no cached user available - clearing auth state")
                await MainActor.run {
                    currentAuthUser = nil
                    isAuthenticated = false
                }
                apiClient.clearAuthenticationState()
                return false
            }
        }
    }

    /// Start periodic session validation
    private func startSessionValidation() {
        stopSessionValidation() // Clear any existing timer

        sessionValidationTimer = Timer.scheduledTimer(withTimeInterval: sessionValidationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                Self.logger.info("⏰ [SESSION-TIMER] Session validation timer triggered")
                _ = await self?.validateSession()
            }
        }

        Self.logger.debug("⏰ Started session validation timer")
    }

    /// Stop session validation
    private func stopSessionValidation() {
        sessionValidationTimer?.invalidate()
        sessionValidationTimer = nil
        Self.logger.debug("⏰ Stopped session validation timer")
    }

    /// Validate stored session with the server
    private func validateStoredSession() async {
        // Only validate if we think we're authenticated
        guard isAuthenticated else {
            Self.logger.info("🔄 No authenticated session to validate")
            return
        }

        do {
            Self.logger.info("🔄 Validating stored session with server...")

            // Use getSession which should use the token we set
            let response = try await apiClient.getSession()

            // Update user data with fresh data from server
            currentAuthUser = response.user
            Self.logger.info("✅ Session validated successfully with server")

            // Update stored user data
            let userData = AuthUserData(
                userId: response.user.id,
                email: response.user.email,
                name: response.user.name,
                image: response.user.image,
                emailVerified: response.user.emailVerified,
                createdAt: response.user.createdAt,
                updatedAt: response.user.updatedAt
            )
            try? authTokenManager.saveUserData(userData)

        } catch {
            Self.logger.error("❌ Session validation failed: \(error)")
            // Don't immediately clear the session - it might be a network error
            // Only clear if it's specifically an unauthorized error
            if case AuthClientError.unauthorized = error {
                Self.logger.warning("⚠️ Session is no longer valid, clearing stored session")
                isAuthenticated = false
                currentAuthUser = nil
                await clearStoredSession()
            } else {
                Self.logger.warning("⚠️ Session validation failed but keeping session for offline use: \(error)")
            }
        }
    }

    /// Check for existing authentication state
    private func updateAuthenticationState() async {
        Self.logger.info("🔄 updateAuthenticationState() called")

        // CRITICAL FIX: Check for stored Better Auth session token in Keychain first
        if let storedToken = authTokenManager.loadToken() {
            Self.logger.info("🔄 Found stored Better Auth session token in Keychain")

            // Try to decode user info from the token or use stored user data
            if let userData = try? authTokenManager.loadUserData() {
                Self.logger.info("🔄 Found stored user data - restoring offline session")

                // Restore user state immediately for offline use
                currentAuthUser = APIUser(
                    id: userData.userId,
                    email: userData.email,
                    name: userData.name,
                    image: userData.image,
                    emailVerified: userData.emailVerified,
                    createdAt: userData.createdAt,
                    updatedAt: userData.updatedAt
                )
                isAuthenticated = true

                // Set the token in API client
                apiClient.setBetterAuthSessionToken(storedToken.accessToken)

                Self.logger.info("✅ Offline session restored for user: \(userData.email)")
                return // Exit early - we're authenticated offline
            } else {
                // We have a token but no user data - try network validation
                Self.logger.info("🔄 Have token but no user data - attempting network validation")

                // Set the token in API client for restoration attempt
                apiClient.setBetterAuthSessionToken(storedToken.accessToken)

                // Proceed with standard cookie-based session restoration
                sessionRestorationTask = Task { @MainActor in
                    do {
                        Self.logger.info("🔄 Attempting session validation with existing cookies")
                        let response = try await apiClient.validateExistingSession()

                        // Success - update authentication state
                        currentAuthUser = response.user
                        isAuthenticated = true

                        // Store user data for future offline use
                        try? authTokenManager.saveUserData(AuthUserData(from: response.user))

                        startSessionValidation()

                        Self.logger.info("✅ Successfully restored session for user: \(response.user.email)")
                    } catch {
                        Self.logger.warning("⚠️ Session restoration failed: \(error.localizedDescription)")

                        // Clear invalid token from Keychain since session is invalid
                        do {
                            try authTokenManager.clearToken()
                            Self.logger.info("🗑️ Cleared invalid token from Keychain")
                        } catch {
                            Self.logger.warning("⚠️ Failed to clear invalid token: \(error)")
                        }

                        // Session is truly invalid - user needs to sign in again
                        currentAuthUser = nil
                        isAuthenticated = false
                    }
                }
                return // Exit early since we're handling restoration with stored token
            }
        } else {
            Self.logger.info("🔄 No stored Better Auth token found in Keychain")
        }

        // Fallback: Check for user in API client memory and attempt cookie-based restoration
        await attemptCookieBasedRestoration()
    }

    /// Attempt cookie-based session restoration (fallback method)
    private func attemptCookieBasedRestoration() async {
        let apiUser = apiClient.getAuthUser()

        if let apiUser = apiUser {
            await MainActor.run {
                currentAuthUser = apiUser
                isAuthenticated = true
            }

            // Start validation for existing session
            startSessionValidation()

            Self.logger.info("🔄 Restored authentication state from memory for user: \(apiUser.email)")
        } else if apiClient.hasCookieSession() {
            Self.logger.info("🔄 No user in memory but cookies exist, deferring session validation")

            // Store a task that can be triggered later when network is needed
            sessionRestorationTask = Task { @MainActor in
                Self.logger.info("🔄 Session restoration task created but not executing immediately")
                // Task is created but won't execute network call until explicitly needed
            }

            // Remain unauthenticated for now
            currentAuthUser = nil
            isAuthenticated = false

            Self.logger.info("🔄 Deferred session restoration - will validate when network access is needed")
        } else {
            Self.logger.info("🔄 No user in memory and no cookies - user needs to authenticate")
            currentAuthUser = nil
            isAuthenticated = false
        }
    }

    /// Validate session when network access is actually needed
    public func validateSessionIfNeeded() async -> Bool {
        // If already authenticated, just return true
        if isAuthenticated && currentAuthUser != nil {
            return true
        }

        // If we have cookies, try to validate now
        if apiClient.hasCookieSession() {
            do {
                Self.logger.info("🔄 Attempting deferred session validation")
                if try await validateCurrentSession() {
                    Self.logger.info("✅ Deferred session validation successful")
                    startSessionValidation()
                    return true
                }
            } catch {
                Self.logger.warning("⚠️ Deferred session validation failed: \(error.localizedDescription)")
            }
        }

        return false
    }

    /// Wait for session restoration to complete (if in progress)
    public func waitForSessionRestoration() async {
        if let task = sessionRestorationTask {
            Self.logger.info("🔄 Waiting for session restoration to complete...")
            await task.value
            sessionRestorationTask = nil
            Self.logger.info("🔄 Session restoration wait complete")
        }
    }

    // MARK: - Helper Methods

    /// Clear all authentication state
    public func clearAuthenticationState() {
        Self.logger.info("🧹 Clearing authentication state")

        // Clear tokens from Keychain
        do {
            try authTokenManager.clearToken()
            Self.logger.info("🗑️ Successfully cleared auth tokens from Keychain during state clear")
        } catch {
            Self.logger.warning("⚠️ Failed to clear tokens from Keychain during state clear: \(error)")
        }

        currentAuthUser = nil
        isAuthenticated = false
        lastError = nil

        stopSessionValidation()
    }

    deinit {
        // Timer cleanup happens in stopSessionValidation which is called from the init
        // No need to do async cleanup in deinit
    }
}

// MARK: - Authentication Service Errors

/// Authentication service errors
public enum AuthServiceError: Error, LocalizedError {
    case signInFailed(Error)
    case signUpFailed(Error)
    case signOutFailed(Error)
    case sessionValidationFailed(Error)
    case notAuthenticated
    case invalidCredentials
    case networkError(Error)
    case unknownError(Error)

    /// Returns a localization key for this error
    public var localizationKey: String {
        switch self {
        case .signInFailed:
            return "auth.error.general"
        case .signUpFailed:
            return "auth.error.general"
        case .signOutFailed:
            return "error.operation_failed"
        case .sessionValidationFailed:
            return "error.operation_failed"
        case .notAuthenticated:
            return "error.unauthorized"
        case .invalidCredentials:
            return "auth.error.invalid_credentials"
        case .networkError:
            return "error.network_message"
        case .unknownError:
            return "error.unknown"
        }
    }

    /// Returns any associated error for string formatting
    public var associatedError: Error? {
        switch self {
        case let .signOutFailed(error),
             let .sessionValidationFailed(error),
             let .networkError(error),
             let .unknownError(error):
            return error
        default:
            return nil
        }
    }

    public var errorDescription: String? {
        // For backward compatibility, return a basic English description
        // Views should use localizationKey for proper localization
        switch self {
        case .signInFailed, .signUpFailed:
            return "Authentication failed. Please try again."
        case .signOutFailed:
            return "Sign out failed"
        case .sessionValidationFailed:
            return "Session validation failed"
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error"
        case .unknownError:
            return "Unknown error"
        }
    }

    public var failureReason: String? {
        switch self {
        case .signInFailed, .signUpFailed:
            return "Invalid credentials"
        case .sessionValidationFailed:
            return "Session expired"
        case .notAuthenticated:
            return "User not signed in"
        case .invalidCredentials:
            return "Invalid credentials"
        case .networkError:
            return "Network connection issue"
        case .signOutFailed, .unknownError:
            return "Unexpected error"
        }
    }
}

// MARK: - AuthServiceError Localization Extension

public extension AuthServiceError {
    /// Returns a fully localized error message for display in UI
    /// This method should be called from MainActor contexts (Views, ViewModels)
    @MainActor
    func localizedMessage() -> String {
        if let associatedError = associatedError {
            // For errors with associated errors, format the message
            return String(format: L(localizationKey), associatedError.localizedDescription)
        } else {
            // For simple errors, just use the localization key
            return L(localizationKey)
        }
    }
}
