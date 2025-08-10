import Combine
import Foundation

// MARK: - API Response Types

/// Response from Better Auth sign in/session endpoints
public struct AuthResponse: Codable {
    public let user: APIUser
    public let token: String

    public init(user: APIUser, token: String) {
        self.user = user
        self.token = token
    }
}

/// Response from session validation endpoint
/// Better Auth returns either a session object or null
public struct SessionResponse: Codable {
    public let user: APIUser
    public let session: SessionInfo?

    // Token is optional - Better Auth doesn't always return it
    // We'll synthesize it from the session token if needed
    public var token: String {
        // If we have a stored session token, use that
        // Otherwise return empty string (session cookie auth)
        return "" // Token is managed via cookies, not in response
    }

    public init(user: APIUser, session: SessionInfo? = nil) {
        self.user = user
        self.session = session
    }
}

/// Better Auth session information
public struct SessionInfo: Codable {
    public let id: String
    public let userId: String?
    public let expiresAt: String?

    public init(id: String, userId: String? = nil, expiresAt: String? = nil) {
        self.id = id
        self.userId = userId
        self.expiresAt = expiresAt
    }
}

// MARK: - API Client Protocol

/// Protocol defining the auth client interface for authentication
@MainActor
public protocol AuthClientProtocol: Sendable {
    /// Current authenticated user (if any)
    var currentAuthUser: APIUser? { get }

    /// Check if there are session cookies available
    func hasCookieSession() -> Bool

    /// Get the currently cached auth user
    func getAuthUser() -> APIUser?

    /// Set the Better Auth session token for API requests
    func setBetterAuthSessionToken(_ token: String)

    /// Clear authentication state
    func clearAuthenticationState()

    /// Sign up with email and password
    func signUp(email: String, password: String, name: String?) async throws -> AuthResponse

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> AuthResponse

    /// Sign out current user
    func signOut() async throws

    /// Get current session (validate existing session)
    func getSession() async throws -> SessionResponse

    /// Validate existing session (cookie-based)
    func validateExistingSession() async throws -> SessionResponse
}

// MARK: - Auth Client Errors

public enum AuthClientError: Error, LocalizedError {
    case unauthorized
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case invalidURL
    case unknownError(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized access"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case let .decodingError(error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case let .unknownError(message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Real Auth Client Implementation

/// Real implementation of AuthClientProtocol for production use
@MainActor
public final class AuthClient: AuthClientProtocol {
    private static let logger = Logger(category: "AuthClient")

    // MARK: - Properties

    public private(set) var currentAuthUser: APIUser?
    private var sessionToken: String?
    private var sessionCookies: [HTTPCookie] = []
    private let authEndpoint: String
    private let urlSession: URLSession

    // MARK: - Initialization

    public init(authEndpoint: String = "http://localhost:3001/api/auth") {
        self.authEndpoint = authEndpoint

        // Configure URLSession with cookie handling
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared

        urlSession = URLSession(configuration: configuration)

        // AuthClient initialized
    }

    // MARK: - AuthClientProtocol Implementation

    public func hasCookieSession() -> Bool {
        // Check if we have Better Auth session cookies
        if let url = URL(string: authEndpoint),
           let cookies = HTTPCookieStorage.shared.cookies(for: url)
        {
            let hasAuthCookie = cookies.contains { cookie in
                cookie.name.contains("better-auth.session") ||
                    cookie.name.contains("auth-token") ||
                    cookie.name == "better-auth.session_token"
            }
            return hasAuthCookie
        }
        return false
    }

    public func getAuthUser() -> APIUser? {
        return currentAuthUser
    }

    public func setBetterAuthSessionToken(_ token: String) {
        sessionToken = token
        // Session token set
    }

    public func clearAuthenticationState() {
        currentAuthUser = nil
        sessionToken = nil
        sessionCookies.removeAll()

        // Clear cookies from storage
        if let url = URL(string: authEndpoint) {
            HTTPCookieStorage.shared.cookies(for: url)?.forEach { cookie in
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        // Authentication state cleared
    }

    public func signUp(email: String, password: String, name: String?) async throws -> AuthResponse {
        Self.logger.info("Signing up: \(email)")

        let signUpPath = "/sign-up/email"
        let fullURLString = "\(authEndpoint)\(signUpPath)"

        guard let url = URL(string: fullURLString) else {
            Self.logger.error("❌ Invalid URL: \(fullURLString)")
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password,
            "name": name ?? "", // Better Auth expects name field, default to empty string
        ]

        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                // Parse response
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

                // Store auth state
                currentAuthUser = authResponse.user
                sessionToken = authResponse.token

                // Store cookies
                if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                    sessionCookies = cookies
                }

                // If no session cookie but we have a token, create a cookie manually
                // This is a workaround for Better Auth when cookies aren't being set properly
                if sessionToken != nil && !hasCookieSession() {
                    createSessionCookie(from: authResponse.token, for: url)
                }

                Self.logger.info("Sign up successful")
                return authResponse

            case 401:
                throw AuthClientError.unauthorized

            case 409:
                // Conflict - user already exists
                Self.logger.error("❌ Sign up failed - user already exists")
                throw AuthClientError.unknownError("An account with this email already exists")

            default:
                Self.logger.error("❌ Sign up failed with status: \(httpResponse.statusCode)")
                throw AuthClientError.unknownError("Server returned status \(httpResponse.statusCode)")
            }

        } catch let error as DecodingError {
            Self.logger.error("❌ Failed to decode response: \(error)")
            throw AuthClientError.decodingError(error)
        } catch {
            Self.logger.error("❌ Network request failed: \(error)")
            throw AuthClientError.networkError(error)
        }
    }

    public func signIn(email: String, password: String) async throws -> AuthResponse {
        Self.logger.info("Signing in: \(email)")

        let signInPath = "/sign-in/email"
        let fullURLString = "\(authEndpoint)\(signInPath)"

        guard let url = URL(string: fullURLString) else {
            Self.logger.error("❌ Invalid URL: \(fullURLString)")
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "email": email,
            "password": password,
        ]

        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                // Parse response
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)

                // Store auth state
                currentAuthUser = authResponse.user
                sessionToken = authResponse.token

                // Store cookies
                if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                    sessionCookies = cookies
                }

                // If no session cookie but we have a token, create a cookie manually
                // This is a workaround for Better Auth when cookies aren't being set properly
                if sessionToken != nil && !hasCookieSession() {
                    createSessionCookie(from: authResponse.token, for: url)
                }

                Self.logger.info("Sign in successful")
                return authResponse

            case 401:
                throw AuthClientError.unauthorized

            default:
                Self.logger.error("❌ Sign in failed with status: \(httpResponse.statusCode)")
                throw AuthClientError.unknownError("Server returned status \(httpResponse.statusCode)")
            }

        } catch let error as DecodingError {
            Self.logger.error("❌ Failed to decode response: \(error)")
            throw AuthClientError.decodingError(error)
        } catch {
            Self.logger.error("❌ Network request failed: \(error)")
            throw AuthClientError.networkError(error)
        }
    }

    public func signOut() async throws {
        Self.logger.info("Signing out")

        guard let url = URL(string: "\(authEndpoint)/sign-out") else {
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Add session token if available
        if let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                clearAuthenticationState()
                // Sign out successful
            } else {
                Self.logger.error("❌ Sign out failed with status: \(httpResponse.statusCode)")
                // Clear state anyway on sign out attempt
                clearAuthenticationState()
            }

        } catch {
            Self.logger.error("❌ Sign out request failed: \(error)")
            // Clear state anyway on sign out attempt
            clearAuthenticationState()
            throw AuthClientError.networkError(error)
        }
    }

    public func getSession() async throws -> SessionResponse {
        // Getting current session

        guard let url = URL(string: "\(authEndpoint)/get-session") else {
            throw AuthClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Add session token if available
        if let token = sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // Adding Bearer token to request
        } else {
            // No session token available
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                // Better Auth returns null for no session
                if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                    Self.logger.warning("⚠️ Get session returned null - no active session")
                    throw AuthClientError.unauthorized
                }

                let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)

                // Update current user
                currentAuthUser = sessionResponse.user
                // Note: Better Auth doesn't return token in getSession, uses cookies
                // Keep existing token if we have one
                if sessionToken == nil || sessionToken?.isEmpty == true {
                    // Token is managed via cookies
                    Self.logger.debug("📝 Session validated via cookies, no token in response")
                }

                // Session validated
                return sessionResponse

            case 401:
                throw AuthClientError.unauthorized

            default:
                Self.logger.error("❌ Get session failed with status: \(httpResponse.statusCode)")
                throw AuthClientError.unknownError("Server returned status \(httpResponse.statusCode)")
            }

        } catch let error as DecodingError {
            Self.logger.error("❌ Failed to decode session response: \(error)")
            throw AuthClientError.decodingError(error)
        } catch {
            Self.logger.error("❌ Session request failed: \(error)")
            throw AuthClientError.networkError(error)
        }
    }

    public func validateExistingSession() async throws -> SessionResponse {
        // Validating existing session

        // First check if we have session cookies
        guard hasCookieSession() else {
            // No session cookies found
            throw AuthClientError.unauthorized
        }

        // Try to get session using cookies
        return try await getSession()
    }

    // MARK: - Private Methods

    /// Create a session cookie from the access token
    /// This is a workaround for when Better Auth doesn't set cookies properly
    private func createSessionCookie(from token: String, for url: URL) {
        guard let host = url.host else {
            Self.logger.error("❌ Failed to extract host from URL: \(url)")
            return
        }

        // For localhost, we need to be more specific about the domain
        // Don't include the port in the domain
        let domain = host == "localhost" ? "localhost" : host.replacingOccurrences(of: ":3001", with: "")

        // Create auth token cookie
        let authTokenCookie = HTTPCookie(properties: [
            .name: "auth-token",
            .value: token,
            .domain: domain,
            .path: "/",
            .secure: "FALSE", // Always false for localhost
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 7), // 7 days
        ])

        // Create better-auth session cookie
        let sessionCookie = HTTPCookie(properties: [
            .name: "better-auth.session_token",
            .value: token,
            .domain: domain,
            .path: "/",
            .secure: "FALSE", // Always false for localhost
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 7), // 7 days
        ])

        if let authTokenCookie = authTokenCookie {
            HTTPCookieStorage.shared.setCookie(authTokenCookie)
        }

        if let sessionCookie = sessionCookie {
            HTTPCookieStorage.shared.setCookie(sessionCookie)
        }
    }
}

// Logger extension moved to Core/Logger+Extensions.swift
