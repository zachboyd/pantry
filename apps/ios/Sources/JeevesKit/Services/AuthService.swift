import Apollo
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
    var tokenManager: AuthTokenManager { get }
    var permissionService: PermissionServiceProtocol? { get }

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

    private let authClient: AuthClientProtocol
    private let authTokenManager: AuthTokenManager
    private let _permissionService: PermissionServiceProtocol?
    private let apolloClient: ApolloClient?

    // Published state for SwiftUI integration
    public var currentAuthUser: APIUser?
    public var isAuthenticated = false
    public var isLoading = false
    public var lastError: String?

    public var currentAuthUserId: String? {
        currentAuthUser?.id
    }

    /// Expose authTokenManager for other services that need it (e.g., ApolloClientService)
    public var tokenManager: AuthTokenManager {
        authTokenManager
    }

    /// Expose permissionService for creating PermissionProvider
    public var permissionService: PermissionServiceProtocol? {
        _permissionService
    }

    // Session validation (simplified)
    private var sessionValidationTimer: Timer?
    private let sessionValidationInterval: TimeInterval = 30 * 60 // 30 minutes

    // Session restoration
    private var sessionRestorationTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(authClient: AuthClientProtocol, authTokenManager: AuthTokenManager, apolloClient: ApolloClient? = nil, permissionService: PermissionServiceProtocol? = nil) {
        self.authClient = authClient
        self.authTokenManager = authTokenManager
        self.apolloClient = apolloClient
        _permissionService = permissionService

        // AuthService initializing

        // Check for existing session synchronously first
        if let storedToken = authTokenManager.loadToken() {
            // Found stored auth token in keychain during init

            // Try to load auth user data
            if let authUserData = try? authTokenManager.loadUserData() {
                // Found stored auth user data - setting authenticated state

                // Restore auth user state immediately
                currentAuthUser = APIUser(
                    id: authUserData.id,
                    email: authUserData.email,
                    name: authUserData.name,
                    image: authUserData.image,
                    emailVerified: authUserData.emailVerified,
                    createdAt: authUserData.createdAt,
                    updatedAt: authUserData.updatedAt,
                )
                isAuthenticated = true

                // Set the token in API client
                authClient.setBetterAuthSessionToken(storedToken.accessToken)

                // Session restored from keychain
            }
        }

        // Validate the session asynchronously with the server
        // This ensures the stored token is still valid
        Task {
            // Add a small delay to avoid immediate validation issues during app startup
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Only validate if we're actually authenticated
            if isAuthenticated {
                await validateStoredToken()
            }
        }

        // AuthService initialized
    }

    // MARK: - AuthServiceProtocol Compatibility

    public var currentUser: User? {
        guard let apiUser = currentAuthUser else { return nil }
        // Note: This is a temporary User object with limited data from auth
        // The real business user will be loaded by UserService
        // We create a placeholder UUID since we don't have the business user ID yet
        return User(
            id: LowercaseUUID(), // Placeholder - real business user ID will be loaded by UserService
            email: apiUser.email,
            name: apiUser.name,
            createdAt: DateUtilities.dateFromGraphQLOrNow(apiUser.createdAt),
        )
    }

    // MARK: - Authentication Methods

    /// Sign in with email and password
    public func signIn(email: String, password: String) async throws -> String {
        // Signing in user

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            // Making HTTP request to API
            let response = try await authClient.signIn(email: email, password: password)

            // Save authentication token to Keychain if provided
            // Note: Better Auth provides a token in the response, but the main authentication
            // relies on HTTP session cookies. We'll store what's available for logging purposes.
            if !response.token.isEmpty {
                do {
                    // Note: Better Auth doesn't provide session expiration in the sign-in response
                    // We'll use a default expiration of 7 days for now
                    let authToken = AuthToken(
                        accessToken: response.token,
                        refreshToken: nil, // Better Auth doesn't provide separate refresh token
                        userId: LowercaseUUID(uuidString: response.user.id),
                        expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 7), // Default to 7 days
                    )
                    try authTokenManager.saveToken(authToken)
                    // Better Auth session token saved to Keychain

                    // CRITICAL FIX: Set the token in API client for session restoration
                    authClient.setBetterAuthSessionToken(response.token)
                } catch {
                    Self.logger.warning("⚠️ Failed to save token to Keychain: \(error)")
                    // Continue with authentication even if token save fails
                }
            } else {
                // No token provided in sign-in response
            }

            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
                isLoading = false
            }

            // Store auth user data for offline use
            do {
                try authTokenManager.saveUserData(AuthUserData(from: response.user))
                // Auth user data saved for offline use
            } catch {
                Self.logger.warning("⚠️ Failed to save user data: \(error)")
                // Continue - this is not critical for sign in
            }

            // Start session validation
            startSessionValidation()

            // Sign in successful
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
        // Signing up user

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            let response = try await authClient.signUp(email: email, password: password, name: nil)

            // Store token in token manager
            // Note: Better Auth doesn't provide session expiration in the sign-up response
            // We'll use a default expiration of 7 days for now
            let authToken = AuthToken(
                accessToken: response.token,
                refreshToken: nil,
                userId: LowercaseUUID(uuidString: response.user.id),
                expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 7), // Default to 7 days
            )

            try authTokenManager.saveToken(authToken)
            // Token saved successfully

            // Update auth state
            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
                isLoading = false
                lastError = nil
            }

            // Save auth user data for offline use
            do {
                try authTokenManager.saveUserData(AuthUserData(from: response.user))
                // Auth user data saved for offline use
            } catch {
                Self.logger.warning("⚠️ Failed to save user data: \(error)")
                // Continue - this is not critical for sign up
            }

            // Start session validation
            startSessionValidation()

            // Sign up successful

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
        // Signing out current user

        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            try await authClient.signOut()

            // Clear tokens from Keychain
            do {
                try authTokenManager.clearToken()
                // Auth tokens cleared from Keychain
            } catch {
                Self.logger.warning("⚠️ Failed to clear tokens from Keychain: \(error)")
                // Continue with sign out even if token clear fails
            }

            await MainActor.run {
                currentAuthUser = nil
                isAuthenticated = false
                isLoading = false
            }

            // Permissions removed - no longer needed

            // Stop session validation
            stopSessionValidation()

            // Sign out successful

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

    /// Load user permissions from backend - DEPRECATED
    /// Permissions have been removed from the User model
    public func loadUserPermissions() async {
        // Permissions removed - this method is now a no-op
    }

    /// Clear stored session (used when session is invalid)
    public func clearStoredSession() async {
        // Clearing stored session due to validation failure

        // Clear tokens from Keychain
        do {
            try authTokenManager.clearToken()
            // Cleared auth token from Keychain
        } catch {
            Self.logger.warning("⚠️ Failed to clear auth token: \(error)")
        }

        // Clear API client state
        authClient.clearAuthenticationState()

        // Clear permissions
        await permissionService?.clearPermissions()

        // Clear local state
        await MainActor.run {
            currentAuthUser = nil
            isAuthenticated = false
            lastError = nil
        }

        // Stop session validation
        stopSessionValidation()

        // Stored session cleared
    }

    /// Validate current session
    public func validateCurrentSession() async throws -> Bool {
        Self.logger.debug("📋 Getting current session")

        do {
            let response = try await authClient.getSession()

            await MainActor.run {
                currentAuthUser = response.user
                isAuthenticated = true
            }

            // Note: Better Auth's getSession doesn't return a token, only session info
            // The token is managed via cookies, so we keep our existing stored token
            if authTokenManager.loadToken() != nil {
                Self.logger.debug("🔐 Keeping existing stored token during session validation")
            } else {
                Self.logger.debug("🔐 No token to store - session validated via cookies")
            }

            // Session validated
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
            if let cachedUser = authClient.getAuthUser() {
                // Restoring user from API client cache
                await MainActor.run {
                    currentAuthUser = cachedUser
                    isAuthenticated = true
                }
                // Successfully restored auth state from cache
                return true
            } else {
                // Session validation failed and no cached user available - clearing auth state
                await MainActor.run {
                    currentAuthUser = nil
                    isAuthenticated = false
                }
                authClient.clearAuthenticationState()
                return false
            }
        }
    }

    /// Start periodic session validation
    private func startSessionValidation() {
        stopSessionValidation() // Clear any existing timer

        sessionValidationTimer = Timer.scheduledTimer(withTimeInterval: sessionValidationInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Session validation timer triggered
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

    /// Validate stored token with the server
    private func validateStoredToken() async {
        // Only validate if we think we're authenticated
        guard isAuthenticated else {
            // No authenticated session to validate
            return
        }

        // First check if the stored token is expired
        if let storedToken = authTokenManager.loadToken() {
            // Check if token has expired
            if !storedToken.isValid {
                Self.logger.warning("⚠️ Stored token has expired")
                await handleInvalidToken()
                return
            }

            // Check if token needs refresh (within 5 minutes of expiry)
            if storedToken.needsRefresh {
                // Token expires soon, should refresh
                // In the future, implement token refresh here
            }
        } else {
            Self.logger.warning("⚠️ No stored token found during validation")
            await handleInvalidToken()
            return
        }

        // Now validate with the server
        do {
            // Validating token with server...

            // Use getSession which includes the Bearer token
            let response = try await authClient.getSession()

            // Update user data with fresh data from server
            await MainActor.run {
                currentAuthUser = response.user
            }
            // Token validated successfully with server

            // Update stored auth user data
            let authUserData = AuthUserData(from: response.user)
            try? authTokenManager.saveUserData(authUserData)

            // Note: Better Auth's getSession doesn't return a token
            // Keep the existing token if we have one
            Self.logger.debug("✅ Session validated, keeping existing token for future use")

        } catch {
            // Handle different error types
            if case AuthClientError.unauthorized = error {
                // This is expected with cookie-based auth - the get-session endpoint
                // may not work properly with stored tokens
                Self.logger.debug("Session validation returned unauthorized - this is expected with cookie-based auth")
                // Don't clear the token - cookies are handling the session
            } else {
                // Network error or other issue - keep token for offline use
                Self.logger.debug("Session validation failed (likely network issue) - keeping for offline use")
            }
        }
    }

    /// Handle invalid token by clearing auth state
    private func handleInvalidToken() async {
        // Handling invalid token - clearing auth state

        await MainActor.run {
            isAuthenticated = false
            currentAuthUser = nil
        }

        // Clear stored tokens and session
        await clearStoredSession()
    }

    /// Validate stored session with the server (deprecated - use validateStoredToken)
    private func validateStoredSession() async {
        // Only validate if we think we're authenticated
        guard isAuthenticated else {
            // No authenticated session to validate
            return
        }

        do {
            // Validating stored session with server...

            // Use getSession which should use the token we set
            let response = try await authClient.getSession()

            // Update user data with fresh data from server
            currentAuthUser = response.user
            // Session validated successfully with server

            // Update stored auth user data
            let authUserData = AuthUserData(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                image: response.user.image,
                emailVerified: response.user.emailVerified,
                createdAt: response.user.createdAt,
                updatedAt: response.user.updatedAt,
            )
            try? authTokenManager.saveUserData(authUserData)

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
        // updateAuthenticationState() called

        // CRITICAL FIX: Check for stored Better Auth session token in Keychain first
        if let storedToken = authTokenManager.loadToken() {
            // Found stored Better Auth session token in Keychain

            // Try to decode auth user info from the token or use stored auth user data
            if let authUserData = try? authTokenManager.loadUserData() {
                // Found stored auth user data - restoring offline session

                // Restore auth user state immediately for offline use
                currentAuthUser = APIUser(
                    id: authUserData.id,
                    email: authUserData.email,
                    name: authUserData.name,
                    image: authUserData.image,
                    emailVerified: authUserData.emailVerified,
                    createdAt: authUserData.createdAt,
                    updatedAt: authUserData.updatedAt,
                )
                isAuthenticated = true

                // Set the token in API client
                authClient.setBetterAuthSessionToken(storedToken.accessToken)

                // Offline session restored
                return // Exit early - we're authenticated offline
            } else {
                // We have a token but no user data - try network validation
                // Have token but no user data - attempting network validation

                // Set the token in API client for restoration attempt
                authClient.setBetterAuthSessionToken(storedToken.accessToken)

                // Proceed with standard cookie-based session restoration
                sessionRestorationTask = Task { @MainActor in
                    do {
                        // Attempting session validation with existing cookies
                        let response = try await authClient.validateExistingSession()

                        // Success - update authentication state
                        currentAuthUser = response.user
                        isAuthenticated = true

                        // Store auth user data for future offline use
                        try? authTokenManager.saveUserData(AuthUserData(from: response.user))

                        startSessionValidation()

                        // Successfully restored session
                    } catch {
                        Self.logger.warning("⚠️ Session restoration failed: \(error.localizedDescription)")

                        // Clear invalid token from Keychain since session is invalid
                        do {
                            try authTokenManager.clearToken()
                            // Cleared invalid token from Keychain
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
            // No stored Better Auth token found in Keychain
        }

        // Fallback: Check for user in API client memory and attempt cookie-based restoration
        await attemptCookieBasedRestoration()
    }

    /// Attempt cookie-based session restoration (fallback method)
    private func attemptCookieBasedRestoration() async {
        let apiUser = authClient.getAuthUser()

        if let apiUser {
            await MainActor.run {
                currentAuthUser = apiUser
                isAuthenticated = true
            }

            // Start validation for existing session
            startSessionValidation()

            // Restored authentication state from memory
        } else if authClient.hasCookieSession() {
            // No user in memory but cookies exist, deferring session validation

            // Store a task that can be triggered later when network is needed
            sessionRestorationTask = Task { @MainActor in
                // Session restoration task created but not executing immediately
                // Task is created but won't execute network call until explicitly needed
            }

            // Remain unauthenticated for now
            currentAuthUser = nil
            isAuthenticated = false

            // Deferred session restoration - will validate when network access is needed
        } else {
            // No user in memory and no cookies - user needs to authenticate
            currentAuthUser = nil
            isAuthenticated = false
        }
    }

    /// Validate session when network access is actually needed
    public func validateSessionIfNeeded() async -> Bool {
        // If already authenticated, just return true
        if isAuthenticated, currentAuthUser != nil {
            return true
        }

        // If we have cookies, try to validate now
        if authClient.hasCookieSession() {
            do {
                // Attempting deferred session validation
                if try await validateCurrentSession() {
                    // Deferred session validation successful
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
            // Waiting for session restoration to complete...
            await task.value
            sessionRestorationTask = nil
            // Session restoration wait complete
        }
    }

    // MARK: - Helper Methods

    /// Clear all authentication state
    public func clearAuthenticationState() {
        // Clearing authentication state

        // Clear tokens from Keychain
        do {
            try authTokenManager.clearToken()
            // Auth tokens cleared from Keychain during state clear
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
            "auth.error.general"
        case .signUpFailed:
            "auth.error.general"
        case .signOutFailed:
            "error.operation_failed"
        case .sessionValidationFailed:
            "error.operation_failed"
        case .notAuthenticated:
            "error.unauthorized"
        case .invalidCredentials:
            "auth.error.invalid_credentials"
        case .networkError:
            "error.network_message"
        case .unknownError:
            "error.unknown"
        }
    }

    /// Returns any associated error for string formatting
    public var associatedError: Error? {
        switch self {
        case let .signOutFailed(error),
             let .sessionValidationFailed(error),
             let .networkError(error),
             let .unknownError(error):
            error
        default:
            nil
        }
    }

    public var errorDescription: String? {
        // For backward compatibility, return a basic English description
        // Views should use localizationKey for proper localization
        switch self {
        case .signInFailed, .signUpFailed:
            "Authentication failed. Please try again."
        case .signOutFailed:
            "Sign out failed"
        case .sessionValidationFailed:
            "Session validation failed"
        case .notAuthenticated:
            "User not authenticated"
        case .invalidCredentials:
            "Invalid email or password"
        case .networkError:
            "Network error"
        case .unknownError:
            "Unknown error"
        }
    }

    public var failureReason: String? {
        switch self {
        case .signInFailed, .signUpFailed:
            "Invalid credentials"
        case .sessionValidationFailed:
            "Session expired"
        case .notAuthenticated:
            "User not signed in"
        case .invalidCredentials:
            "Invalid credentials"
        case .networkError:
            "Network connection issue"
        case .signOutFailed, .unknownError:
            "Unexpected error"
        }
    }
}

// MARK: - AuthServiceError Localization Extension

public extension AuthServiceError {
    /// Returns a fully localized error message for display in UI
    /// This method should be called from MainActor contexts (Views, ViewModels)
    @MainActor
    func localizedMessage() -> String {
        if let associatedError {
            // For errors with associated errors, format the message
            String(format: L(localizationKey), associatedError.localizedDescription)
        } else {
            // For simple errors, just use the localization key
            L(localizationKey)
        }
    }
}
