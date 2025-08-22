/*
 SocialAuthenticationHandler.swift
 JeevesKit

 Handles social authentication OAuth flows using ASWebAuthenticationSession
 */

import AuthenticationServices
import Foundation
import SwiftUI

/// Protocol for handling social authentication flows
@MainActor
public protocol SocialAuthenticationHandlerProtocol {
    func authenticate(provider: String, callbackScheme: String) async throws -> SocialAuthResponse
}

/// Response from social authentication
public struct SocialAuthResponse: Sendable {
    public let token: String?
    public let code: String?
    public let state: String?
    public let error: String?

    public init(token: String? = nil, code: String? = nil, state: String? = nil, error: String? = nil) {
        self.token = token
        self.code = code
        self.state = state
        self.error = error
    }
}

/// Handler for social authentication using ASWebAuthenticationSession
@MainActor
public class SocialAuthenticationHandler: NSObject, SocialAuthenticationHandlerProtocol {
    private static let logger = Logger.auth

    /// Window anchor for presenting the authentication session
    private weak var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?

    override public init() {
        super.init()
        Self.logger.info("📱 SocialAuthenticationHandler initialized")
    }

    /// Authenticate with a social provider
    /// - Parameters:
    ///   - provider: The social provider (e.g., "google")
    ///   - callbackScheme: The URL scheme for callbacks (e.g., "jeeves")
    /// - Returns: Authentication response with tokens or error
    public func authenticate(provider: String, callbackScheme _: String) async throws -> SocialAuthResponse {
        Self.logger.info("🌐 Starting OAuth flow for provider: \(provider)")

        // Get the OAuth URL from the backend
        let oauthURL = try await getOAuthURL(provider: provider)
        Self.logger.info("🔗 Initial OAuth URL: \(oauthURL.absoluteString)")

        return try await withCheckedThrowingContinuation { continuation in
            // Since the OAuth callback goes to localhost:3001, we need to handle this differently
            // We'll use nil for callbackURLScheme to monitor the entire OAuth flow
            // and detect when the authentication completes at the backend
            let authSession = ASWebAuthenticationSession(
                url: oauthURL,
                callbackURLScheme: nil, // nil to monitor all URLs including localhost
            ) { callbackURL, error in
                // Log the final URL if available
                if let finalURL = callbackURL {
                    Self.logger.info("🏁 Final OAuth URL: \(finalURL.absoluteString)")
                } else {
                    Self.logger.info("🏁 OAuth session completed (no final URL available with nil scheme)")
                }
                if let error {
                    if case ASWebAuthenticationSessionError.canceledLogin = error {
                        Self.logger.info("❌ User canceled OAuth login")
                        continuation.resume(throwing: AuthServiceError.socialAuthCanceled)
                    } else {
                        Self.logger.error("❌ OAuth error: \(error)")
                        continuation.resume(throwing: AuthServiceError.socialAuthFailed(error))
                    }
                    return
                }

                // When callbackURLScheme is nil, the session completes when the OAuth flow finishes
                // The backend will have set the session cookie during the callback processing
                // We now need to fetch the session from the backend
                Task {
                    do {
                        Self.logger.info("✅ OAuth flow completed, fetching session from backend")

                        // INTERCEPTION POINT #1: OAuth has completed, backend has created session
                        // At this point, the OAuth provider has authenticated the user and
                        // Better Auth has processed the callback on the backend
                        Self.logger.info("🔍 Intercepting after OAuth completion")

                        // Note: callbackURL is nil when using nil callbackURLScheme
                        // The ASWebAuthenticationSession completes when the OAuth flow finishes
                        // but doesn't provide the final URL since we're not intercepting a specific scheme

                        // Check if cookies were already set by the OAuth flow
                        if let cookies = HTTPCookieStorage.shared.cookies {
                            for cookie in cookies {
                                if cookie.name.hasPrefix("jeeves.session_token") {
                                    Self.logger.info("🍪 Session cookie already present: \(cookie.name)")
                                    Self.logger.debug("🍪 Cookie value: \(cookie.value)")
                                    Self.logger.debug("🍪 Cookie domain: \(cookie.domain)")
                                    Self.logger.debug("🍪 Cookie path: \(cookie.path)")
                                }
                            }
                        }

                        // Custom session interception logic can go here
                        // For example, you could:
                        // - Store session info in keychain
                        // - Send analytics events
                        // - Update app state
                        // - Validate session before proceeding
                        try await self.handlePostOAuthInterception()

                        // The OAuth flow has completed and the backend has the session
                        // We need to get the session information from the backend
                        let sessionResponse = try await self.getSessionFromBackend()

                        Self.logger.info("✅ Session retrieved successfully")
                        continuation.resume(returning: sessionResponse)
                    } catch {
                        Self.logger.error("❌ Failed to get session after OAuth: \(error)")
                        continuation.resume(throwing: AuthServiceError.socialAuthFailed(error))
                    }
                }
            }

            // Configure the session
            authSession.prefersEphemeralWebBrowserSession = false // Allow SSO
            authSession.presentationContextProvider = self

            // Start the authentication flow
            DispatchQueue.main.async {
                if !authSession.start() {
                    Self.logger.error("❌ Failed to start OAuth session")
                    continuation.resume(throwing: AuthServiceError.socialAuthFailed(nil))
                }
            }
        }
    }

    /// Get OAuth URL from backend
    private func getOAuthURL(provider: String) async throws -> URL {
        Self.logger.info("📡 Requesting OAuth URL for provider: \(provider)")

        // Get the base URL from environment/config
        let baseURL = getAPIBaseURL()

        // Construct the OAuth initiation URL
        // The backend will return a redirect URL to the OAuth provider
        let urlString = "\(baseURL)/api/auth/sign-in/social"

        guard let url = URL(string: urlString) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add disableRedirect to prevent automatic redirect
        struct OAuthRequest: Encodable {
            let provider: String
            let disableRedirect: Bool
        }
        let body = OAuthRequest(provider: provider, disableRedirect: true)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            Self.logger.error("❌ OAuth URL request failed with status: \(httpResponse.statusCode)")
            throw AuthServiceError.socialAuthFailed(nil)
        }

        // Parse the response to get the OAuth URL
        struct OAuthResponse: Codable {
            let url: String
        }

        let oauthResponse = try JSONDecoder().decode(OAuthResponse.self, from: data)

        guard let oauthURL = URL(string: oauthResponse.url) else {
            throw AuthServiceError.invalidURL
        }

        Self.logger.info("✅ OAuth URL received: \(oauthURL)")
        return oauthURL
    }

    /// Parse the callback URL to extract tokens/codes
    private func parseCallbackURL(_ url: URL) -> SocialAuthResponse {
        var response = SocialAuthResponse()

        // Parse query parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                switch item.name {
                case "token":
                    response = SocialAuthResponse(
                        token: item.value,
                        code: response.code,
                        state: response.state,
                        error: response.error,
                    )
                case "code":
                    response = SocialAuthResponse(
                        token: response.token,
                        code: item.value,
                        state: response.state,
                        error: response.error,
                    )
                case "state":
                    response = SocialAuthResponse(
                        token: response.token,
                        code: response.code,
                        state: item.value,
                        error: response.error,
                    )
                case "error":
                    response = SocialAuthResponse(
                        token: response.token,
                        code: response.code,
                        state: response.state,
                        error: item.value,
                    )
                default:
                    break
                }
            }
        }

        // Also check fragment for token (some OAuth providers return tokens in fragment)
        if let fragment = url.fragment {
            let fragmentComponents = fragment.components(separatedBy: "&")
            for component in fragmentComponents {
                let keyValue = component.components(separatedBy: "=")
                if keyValue.count == 2 {
                    switch keyValue[0] {
                    case "access_token":
                        response = SocialAuthResponse(
                            token: keyValue[1],
                            code: response.code,
                            state: response.state,
                            error: response.error,
                        )
                    default:
                        break
                    }
                }
            }
        }

        return response
    }

    /// Get session from backend after OAuth completion
    private func getSessionFromBackend() async throws -> SocialAuthResponse {
        Self.logger.info("📡 Fetching session from backend")

        let baseURL = getAPIBaseURL()
        let urlString = "\(baseURL)/api/auth/session"

        guard let url = URL(string: urlString) else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Create a custom URLSession configuration that handles cookies
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared

        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        // Check if we got a successful response
        guard httpResponse.statusCode == 200 else {
            Self.logger.error("❌ Session fetch failed with status: \(httpResponse.statusCode)")
            throw AuthServiceError.socialAuthFailed(nil)
        }

        // Extract session cookie from the cookies
        var sessionToken: String?
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                if cookie.name.hasPrefix("jeeves.session_token") {
                    sessionToken = cookie.value
                    Self.logger.info("✅ Found session token in cookie: \(cookie.name)")
                    break
                }
            }
        }

        // Parse the session response
        struct BetterAuthSessionResponse: Codable {
            let user: UserInfo?
            let session: SessionData?

            struct UserInfo: Codable {
                let id: String
                let email: String
                let name: String?
            }

            struct SessionData: Codable {
                let id: String
                let userId: String
                let expiresAt: String
            }
        }

        // Try to decode the session response
        if let sessionData = try? JSONDecoder().decode(BetterAuthSessionResponse.self, from: data) {
            Self.logger.info("✅ Session data received for user: \(sessionData.user?.email ?? "unknown")")

            // Return the session token if found
            if let token = sessionToken ?? sessionData.session?.id {
                return SocialAuthResponse(token: token)
            }
        }

        // If we couldn't extract a session, but the OAuth flow completed,
        // return success without a token (the cookie is stored in HTTPCookieStorage)
        Self.logger.info("⚠️ OAuth completed but no explicit session token found, relying on cookie storage")
        return SocialAuthResponse(token: nil)
    }

    /// Handle post-OAuth interception logic
    /// This is called after OAuth completes but before fetching the session
    private func handlePostOAuthInterception() async throws {
        Self.logger.info("🎯 Executing post-OAuth interception logic")

        // Example interception logic:

        // 1. Check for any cookies that might have been set
        let baseURL = getAPIBaseURL()
        if let url = URL(string: baseURL),
           let cookies = HTTPCookieStorage.shared.cookies(for: url)
        {
            Self.logger.info("📦 Found \(cookies.count) cookies for \(baseURL)")
            for cookie in cookies {
                Self.logger.debug("  Cookie: \(cookie.name) = \(cookie.value.prefix(20))...")
            }
        }

        // 2. You could validate that OAuth actually succeeded
        // by checking for expected cookies or making a test request

        // 3. You could trigger app-specific logic here
        // For example, prepare the app state for the new session

        // 4. You could also implement custom session validation
        // or additional security checks before proceeding

        Self.logger.info("✅ Post-OAuth interception complete")
    }

    /// Get API base URL from configuration
    private func getAPIBaseURL() -> String {
        // In production, this should come from your app's configuration
        // For development, using localhost
        #if DEBUG
            return "http://localhost:3001"
        #else
            // TODO: Replace with your production API URL
            return "https://api.jeeves.app"
        #endif
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SocialAuthenticationHandler: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
        else {
            fatalError("No window available for authentication session")
        }
        return window
    }
}

// MARK: - Social Authentication Errors

public enum SocialAuthError: Error, LocalizedError {
    case userCanceled
    case invalidURL
    case invalidResponse
    case authenticationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .userCanceled:
            "User canceled social authentication"
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid server response"
        case let .authenticationFailed(message):
            message
        }
    }
}

// MARK: - AuthServiceError Extensions

public extension AuthServiceError {
    static let socialAuthCanceled = AuthServiceError.unknownError(SocialAuthError.userCanceled)

    static func socialAuthFailed(_ error: Error?) -> AuthServiceError {
        if let error {
            AuthServiceError.networkError(error)
        } else {
            AuthServiceError.unknownError(SocialAuthError.authenticationFailed("Social authentication failed"))
        }
    }

    static let invalidURL = AuthServiceError.unknownError(SocialAuthError.invalidURL)
    static let invalidResponse = AuthServiceError.unknownError(SocialAuthError.invalidResponse)
}
