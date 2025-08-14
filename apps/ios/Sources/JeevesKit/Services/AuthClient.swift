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
        "" // Token is managed via cookies, not in response
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
            "Unauthorized access"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            "Invalid response from server"
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case .invalidURL:
            "Invalid URL"
        case let .unknownError(message):
            "Unknown error: \(message)"
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
                cookie.name.contains("jeeves.session") ||
                    cookie.name.contains("auth-token") ||
                    cookie.name == "jeeves.session_token"
            }
            return hasAuthCookie
        }
        return false
    }

    public func getAuthUser() -> APIUser? {
        currentAuthUser
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

        // Clear any old cookies before sign-up to prevent conflicts
        clearOldCookies()

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

                // Manually handle Set-Cookie header since iOS has issues with localhost cookies
                var setCookieValue: String?
                if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                    for (key, value) in allHeaders {
                        if key.lowercased() == "set-cookie" {
                            setCookieValue = value
                        }
                    }
                }

                // Manually create cookie from Set-Cookie header if iOS didn't store it
                if let setCookieValue {
                    createCookieFromSetCookieHeader(setCookieValue, for: url)
                }

                // Check if we have the proper signed session cookie
                if let allCookies = HTTPCookieStorage.shared.cookies {
                    let authCookies = allCookies.filter { cookie in
                        cookie.name == "jeeves.session_token" ||
                            cookie.name.contains("better-auth") ||
                            cookie.name.contains("jeeves")
                    }

                    if !authCookies.isEmpty {
                        sessionCookies = authCookies
                    }

                    let hasProperCookie = sessionCookies.contains {
                        $0.name == "jeeves.session_token" && $0.value.contains(".")
                    }

                    if !hasProperCookie {
                        Self.logger.error("❌ Better Auth signed session cookie not properly received!")
                    }
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

        // Clear any old cookies before sign-in to prevent conflicts
        clearOldCookies()

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

                // Log and manually handle Set-Cookie header since iOS has issues with localhost cookies
                Self.logger.info("📥 Response headers from sign-in:")
                var setCookieValue: String?
                if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                    for (key, value) in allHeaders {
                        if key.lowercased() == "set-cookie" {
                            Self.logger.info("   \(key): \(value)")
                            setCookieValue = value
                        }
                    }
                }

                // Manually create cookie from Set-Cookie header if iOS didn't store it
                if let setCookieValue {
                    Self.logger.info("🍪 Manually parsing Set-Cookie header")
                    createCookieFromSetCookieHeader(setCookieValue, for: url)
                }

                // Check if we have the proper signed session cookie
                if let allCookies = HTTPCookieStorage.shared.cookies {
                    let authCookies = allCookies.filter { cookie in
                        cookie.name == "jeeves.session_token" ||
                            cookie.name.contains("better-auth") ||
                            cookie.name.contains("jeeves")
                    }

                    if !authCookies.isEmpty {
                        sessionCookies = authCookies
                    }

                    let hasProperCookie = sessionCookies.contains {
                        $0.name == "jeeves.session_token" && $0.value.contains(".")
                    }

                    if !hasProperCookie {
                        Self.logger.error("❌ Better Auth signed session cookie not properly received!")
                    }
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

        // Better Auth uses cookies for authentication, not Bearer tokens
        // The cookies are automatically included by URLSession

        do {
            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            if httpResponse.statusCode >= 200, httpResponse.statusCode < 300 {
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

        // Better Auth uses cookies for session validation, not Bearer tokens
        // The cookies are automatically included by URLSession

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthClientError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200 ... 299:
                // Better Auth returns null for no session
                if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                    // Session validation returning null is expected with cookie-based auth
                    throw AuthClientError.unauthorized
                }

                let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)

                // Update current user
                currentAuthUser = sessionResponse.user
                // Note: Better Auth doesn't return token in getSession, uses cookies
                // Keep existing token if we have one
                if sessionToken == nil || sessionToken?.isEmpty == true {
                    // Token is managed via cookies
                    // Token is managed via cookies
                }

                // Session validated
                return sessionResponse

            case 401:
                throw AuthClientError.unauthorized

            default:
                Self.logger.debug("Get session failed with status: \(httpResponse.statusCode)")
                throw AuthClientError.unknownError("Server returned status \(httpResponse.statusCode)")
            }

        } catch let error as DecodingError {
            Self.logger.debug("Failed to decode session response: \(error)")
            throw AuthClientError.decodingError(error)
        } catch {
            // Session request failures are expected with cookie-based auth
            Self.logger.debug("Session request failed (expected with cookie auth): \(error)")
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

    /// Clear old cookies that might interfere with new authentication
    private func clearOldCookies() {
        if let allCookies = HTTPCookieStorage.shared.cookies {
            let authCookies = allCookies.filter { cookie in
                cookie.name == "jeeves.session_token" ||
                    cookie.name.contains("better-auth") ||
                    cookie.name == "auth-token" ||
                    cookie.name.contains("jeeves")
            }

            for cookie in authCookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    /// Parse Set-Cookie header and manually create cookie
    /// This is a workaround for iOS not properly storing localhost cookies
    private func createCookieFromSetCookieHeader(_ setCookieHeader: String, for url: URL) {
        // Parse the Set-Cookie header
        // Format: jeeves.session_token=<value>; Max-Age=604800; Path=/; HttpOnly; SameSite=Lax
        let components = setCookieHeader.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        guard !components.isEmpty else {
            return
        }

        // Parse name and value from first component
        let nameValue = components[0].split(separator: "=", maxSplits: 1)
        guard nameValue.count == 2 else {
            return
        }

        let cookieName = String(nameValue[0])
        let cookieValue = String(nameValue[1])

        // Only process Better Auth session cookies
        guard cookieName == "jeeves.session_token" else {
            return
        }

        // Create cookie properties
        var cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .name: cookieName,
            .value: cookieValue,
            .domain: url.host ?? "localhost",
            .path: "/",
            .secure: "FALSE", // For localhost development
        ]

        // Parse additional attributes
        for component in components.dropFirst() {
            if component.hasPrefix("Max-Age=") {
                if let maxAge = Int(component.dropFirst(8)) {
                    cookieProperties[.expires] = Date().addingTimeInterval(TimeInterval(maxAge))
                }
            } else if component.hasPrefix("Path=") {
                cookieProperties[.path] = String(component.dropFirst(5))
            } else if component.hasPrefix("Domain=") {
                cookieProperties[.domain] = String(component.dropFirst(7))
            }
        }

        // Create and store the cookie
        if let cookie = HTTPCookie(properties: cookieProperties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        } else {}
    }
}

// Logger extension moved to Core/Logger+Extensions.swift
