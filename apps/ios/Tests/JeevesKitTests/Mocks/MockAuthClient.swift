import Foundation
@testable import JeevesKit

/// Mock implementation of AuthClientProtocol for testing
@MainActor
final class MockAuthClient: AuthClientProtocol {
    // MARK: - Properties for Testing

    var mockUser: APIUser?
    var mockToken: String?
    var shouldFailSignIn = false
    var shouldFailSignOut = false
    var shouldFailGetSession = false
    var signInCallCount = 0
    var signOutCallCount = 0
    var getSessionCallCount = 0

    // MARK: - AuthClientProtocol Implementation

    private(set) var currentAuthUser: APIUser?
    private var hasCookies = false

    func hasCookieSession() -> Bool {
        hasCookies
    }

    func getAuthUser() -> APIUser? {
        currentAuthUser
    }

    func setBetterAuthSessionToken(_ token: String) {
        mockToken = token
        hasCookies = true
    }

    func clearAuthenticationState() {
        currentAuthUser = nil
        mockToken = nil
        hasCookies = false
    }

    func signUp(email: String, password _: String, name: String?) async throws -> AuthResponse {
        signInCallCount += 1

        if shouldFailSignIn {
            throw AuthClientError.unauthorized
        }

        let user = mockUser ?? APIUser(
            id: "test_user_id",
            email: email,
            name: name ?? "Test User",
            image: nil,
            emailVerified: true,
            createdAt: DateUtilities.graphQLStringFromDate(Date()),
            updatedAt: DateUtilities.graphQLStringFromDate(Date()),
        )

        let token = mockToken ?? "test_session_token"

        currentAuthUser = user
        hasCookies = true

        return AuthResponse(user: user, token: token)
    }

    func signIn(email: String, password _: String) async throws -> AuthResponse {
        signInCallCount += 1

        if shouldFailSignIn {
            throw AuthClientError.unauthorized
        }

        let user = mockUser ?? APIUser(
            id: "test_user_id",
            email: email,
            name: "Test User",
            image: nil,
            emailVerified: true,
            createdAt: DateUtilities.graphQLStringFromDate(Date()),
            updatedAt: DateUtilities.graphQLStringFromDate(Date()),
        )

        let token = mockToken ?? "test_session_token"

        currentAuthUser = user
        hasCookies = true

        return AuthResponse(user: user, token: token)
    }

    func signOut() async throws {
        signOutCallCount += 1

        if shouldFailSignOut {
            throw AuthClientError.networkError(NSError(domain: "test", code: 1))
        }

        clearAuthenticationState()
    }

    func getSession() async throws -> SessionResponse {
        getSessionCallCount += 1

        if shouldFailGetSession {
            throw AuthClientError.unauthorized
        }

        guard let user = currentAuthUser else {
            throw AuthClientError.unauthorized
        }

        return SessionResponse(
            user: user,
            session: SessionInfo(
                id: "test-session-id",
                userId: user.id,
                expiresAt: nil,
            ),
        )
    }

    func validateExistingSession() async throws -> SessionResponse {
        guard hasCookies else {
            throw AuthClientError.unauthorized
        }

        return try await getSession()
    }

    func completeSocialSignIn(provider: String, token: String?, code _: String?) async throws -> AuthResponse {
        signInCallCount += 1

        if shouldFailSignIn {
            throw AuthClientError.unauthorized
        }

        let user = mockUser ?? APIUser(
            id: "test_social_user_id",
            email: "\(provider)_user@example.com",
            name: "Test \(provider.capitalized) User",
            image: nil,
            emailVerified: true,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
        )

        currentAuthUser = user
        mockToken = token ?? "test_social_token"
        hasCookies = true

        return AuthResponse(user: user, token: mockToken ?? "")
    }
}
