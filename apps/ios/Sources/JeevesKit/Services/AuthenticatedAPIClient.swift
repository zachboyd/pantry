/*
 AuthenticatedAPIClient.swift
 JeevesKit

 Handles authenticated API requests with session cookie management
 */

import Foundation

/// Client for making authenticated API requests with session cookies
@MainActor
public class AuthenticatedAPIClient {
    private static let logger = Logger.network

    /// Shared instance for convenience
    public static let shared = AuthenticatedAPIClient()

    /// Base URL for API requests
    private var baseURL: String {
        #if DEBUG
            return "http://localhost:3001"
        #else
            // TODO: Replace with your production API URL
            return "https://api.jeeves.app"
        #endif
    }

    /// URLSession configured for cookie handling
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        return URLSession(configuration: configuration)
    }()

    // MARK: - Public Methods

    /// Make an authenticated GET request
    public func get(_ endpoint: String) async throws -> Data {
        try await request(endpoint: endpoint, method: "GET")
    }

    /// Make an authenticated POST request
    public func post(_ endpoint: String, body: Encodable? = nil) async throws -> Data {
        try await request(endpoint: endpoint, method: "POST", body: body)
    }

    /// Make an authenticated PUT request
    public func put(_ endpoint: String, body: Encodable? = nil) async throws -> Data {
        try await request(endpoint: endpoint, method: "PUT", body: body)
    }

    /// Make an authenticated DELETE request
    public func delete(_ endpoint: String) async throws -> Data {
        try await request(endpoint: endpoint, method: "DELETE")
    }

    /// Make an authenticated PATCH request
    public func patch(_ endpoint: String, body: Encodable? = nil) async throws -> Data {
        try await request(endpoint: endpoint, method: "PATCH", body: body)
    }

    // MARK: - Private Methods

    /// Core request method
    private func request(
        endpoint: String,
        method: String,
        body: Encodable? = nil,
    ) async throws -> Data {
        // Construct full URL
        let urlString = endpoint.hasPrefix("http") ? endpoint : "\(baseURL)\(endpoint)"

        guard let url = URL(string: urlString) else {
            Self.logger.error("❌ Invalid URL: \(urlString)")
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add body if provided
        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        // Check for existing session cookies
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (name, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: name)
                if name == "Cookie" {
                    Self.logger.info("🍪 Including session cookie in request")
                }
            }
        }

        Self.logger.info("📡 \(method) \(endpoint)")

        // Make request
        let (data, response) = try await urlSession.data(for: request)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Log response status
        Self.logger.info("📥 Response: \(httpResponse.statusCode)")

        // Check for success (2xx status codes)
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            Self.logger.error("❌ Request failed with status: \(httpResponse.statusCode)")

            // Try to parse error message from response
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.message ?? "Unknown error")
            }

            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return data
    }

    // MARK: - Session Management

    /// Check if we have a valid session cookie
    public func hasSessionCookie() -> Bool {
        guard let url = URL(string: baseURL) else { return false }

        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                if cookie.name.hasPrefix("jeeves.session_token") {
                    Self.logger.info("✅ Found session cookie: \(cookie.name)")
                    return true
                }
            }
        }

        return false
    }

    /// Clear all session cookies
    public func clearSessionCookies() {
        guard let url = URL(string: baseURL) else { return }

        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies {
                if cookie.name.hasPrefix("jeeves") {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                    Self.logger.info("🗑️ Deleted cookie: \(cookie.name)")
                }
            }
        }
    }

    /// Get current session info from backend
    public func getSession() async throws -> AuthSessionResponse {
        let data = try await get("/api/auth/session")
        return try JSONDecoder().decode(AuthSessionResponse.self, from: data)
    }
}

// MARK: - Supporting Types

/// API Error types
public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(String)
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid server response"
        case let .httpError(code):
            "HTTP error: \(code)"
        case let .serverError(message):
            message
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

/// Error response structure
struct ErrorResponse: Codable {
    let message: String?
    let error: String?
}

/// Session response from backend /api/auth/session endpoint
public struct AuthSessionResponse: Codable {
    public let user: AuthUserInfo?
    public let session: AuthSession?

    public struct AuthUserInfo: Codable {
        public let id: String
        public let email: String
        public let name: String?
        public let emailVerified: Bool?
        public let image: String?
        public let createdAt: String?
        public let updatedAt: String?
    }

    public struct AuthSession: Codable {
        public let id: String
        public let userId: String
        public let expiresAt: String
    }
}
