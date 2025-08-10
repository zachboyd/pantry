@preconcurrency import Apollo
@preconcurrency import ApolloAPI
import Foundation

/// Service that manages Apollo GraphQL client configuration and lifecycle
@MainActor
public final class ApolloClientService {
    private static let logger = Logger.graphql

    // MARK: - Properties

    /// Apollo Client instance
    public private(set) var apollo: ApolloClient

    /// Convenience getter for apolloClient
    public var apolloClient: ApolloClient {
        apollo
    }

    /// Expose the Apollo store for cache access
    public private(set) var store: ApolloStore?

    /// Base URL for GraphQL endpoint
    private let graphqlEndpoint: String

    /// Authentication service for token management
    private var authService: (any AuthServiceProtocol)?

    // MARK: - Initialization

    /// Initialize Apollo Client service
    /// - Parameters:
    ///   - endpoint: GraphQL endpoint URL (defaults to localhost:3001/graphql)
    ///   - authService: Authentication service for token management
    public init(
        endpoint: String = "http://localhost:3001/graphql",
        authService: AuthServiceProtocol? = nil
    ) {
        graphqlEndpoint = endpoint
        self.authService = authService

        Self.logger.info("🚀 Initializing Apollo Client service")

        // Create Apollo Client with authentication interceptors
        let (client, store) = Self.createApolloClient(
            endpoint: endpoint,
            authService: authService
        )
        apollo = client
        self.store = store

        Self.logger.info("✅ Apollo Client service initialized")
    }

    // MARK: - Public Methods

    /// Update the auth service after initialization
    /// This recreates the Apollo client to ensure authentication interceptors are properly configured
    public func updateAuthService(_ authService: AuthServiceProtocol?) {
        self.authService = authService

        // CRITICAL: We must recreate the Apollo Client to ensure the authentication
        // interceptors get the updated authService reference. Otherwise, requests
        // will fail with "Authentication required" even when the user is signed in.
        let (client, store) = Self.createApolloClient(
            endpoint: graphqlEndpoint,
            authService: authService
        )
        apollo = client
        self.store = store

        Self.logger.info("🔄 Updated AuthService in ApolloClientService and recreated Apollo Client")
    }

    /// Clear any cached data and reset Apollo Client
    public func clearCache() async {
        Self.logger.info("🧹 Clearing Apollo Client cache")

        apollo.clearCache()
        Self.logger.info("✅ Apollo Client cache cleared successfully")
    }

    /// Enable or disable verbose request/response logging
    /// - Parameter enabled: Whether to enable verbose logging
    public func setVerboseLogging(_ enabled: Bool) {
        RequestLoggingInterceptor.verboseLoggingEnabled = enabled
        Self.logger.info("📊 GraphQL verbose logging: \(enabled ? "enabled" : "disabled")")
    }

    /// Ensure session cookies are set for GraphQL requests
    /// This is a workaround for Better Auth cookie issues
    public func ensureSessionCookies() {
        guard let authService = authService,
              let token = authService.tokenManager.loadToken()
        else {
            Self.logger.warning("⚠️ No auth token available to create cookies")
            return
        }

        // Create cookies for the GraphQL endpoint
        guard let graphQLURL = URL(string: graphqlEndpoint) else { return }

        let domain = graphQLURL.host ?? "localhost"

        // Create session cookie that Better Auth expects
        let sessionCookie = HTTPCookie(properties: [
            .name: "better-auth.session_token",
            .value: token.accessToken,
            .domain: domain,
            .path: "/",
            .secure: "FALSE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 7), // 7 days
        ])

        if let cookie = sessionCookie {
            HTTPCookieStorage.shared.setCookie(cookie)
            Self.logger.debug("🍪 Session cookie configured for domain: \(domain)")
        }
    }

    // MARK: - Private Methods

    /// Create Apollo Client with proper configuration
    /// - Parameters:
    ///   - endpoint: GraphQL endpoint URL
    ///   - authService: Authentication service for token management
    /// - Returns: Tuple of configured Apollo Client and ApolloStore
    private static func createApolloClient(
        endpoint: String,
        authService: AuthServiceProtocol?
    ) -> (ApolloClient, ApolloStore) {
        guard let url = URL(string: endpoint) else {
            logger.error("❌ Invalid GraphQL endpoint URL: \(endpoint)")
            fatalError("Invalid GraphQL endpoint URL: \(endpoint)")
        }

        logger.info("🔧 Creating Apollo Client for endpoint: \(endpoint)")

        // Create the cache
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)

        // Create authentication interceptors
        let authInterceptor = AuthenticationInterceptor(authService: authService)
        let authErrorInterceptor = AuthErrorInterceptor(authService: authService)

        // Configure URLSession with cookie handling to match AuthClient
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpCookieAcceptPolicy = .always
        sessionConfiguration.httpShouldSetCookies = true
        sessionConfiguration.httpCookieStorage = HTTPCookieStorage.shared

        logger.debug("🍪 Configured URLSession with cookie support")

        // Create URLSessionClient with our cookie-enabled configuration
        let urlSessionClient = URLSessionClient(
            sessionConfiguration: sessionConfiguration,
            callbackQueue: nil
        )

        // Create network transport with interceptors and custom URLSessionClient
        let networkTransport = RequestChainNetworkTransport(
            interceptorProvider: InterceptorProvider(
                store: store,
                authInterceptor: authInterceptor,
                authErrorInterceptor: authErrorInterceptor,
                urlSessionClient: urlSessionClient
            ),
            endpointURL: url
        )

        // Create Apollo Client with cache normalization
        // Note: In Apollo iOS 1.x, cache key normalization is handled by the store
        // The default behavior uses the 'id' field as the cache key when available
        let client = ApolloClient(
            networkTransport: networkTransport,
            store: store
        )

        logger.info("✅ Apollo Client created successfully with cache normalization")
        return (client, store)
    }
}

// MARK: - Authentication Interceptor

/// Interceptor that adds authentication headers to GraphQL requests
///
/// Note: Uses @unchecked Sendable because it contains a DispatchQueue for thread-safe operations.
/// The queue ensures thread-safe access to the weak authService reference.
private final class AuthenticationInterceptor: ApolloInterceptor, @unchecked Sendable {
    private static let logger = Logger.auth

    let id: String = UUID().uuidString
    private weak var authService: AuthServiceProtocol?
    private let serialQueue = DispatchQueue(label: "AuthInterceptor", qos: .userInitiated)

    init(authService: AuthServiceProtocol?) {
        self.authService = authService
    }

    func interceptAsync<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping @Sendable (Result<Apollo.GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation & Sendable {
        // Perform authentication check on serial queue to avoid data races
        serialQueue.async { [weak self] in
            guard let self = self else {
                // If self is nil, we still need to continue the chain
                // but we can't add authentication headers
                return
            }

            // Safely check authentication on main actor
            Task { @MainActor in
                await self.processAuthenticationAsync(
                    chain: chain,
                    request: request,
                    response: response,
                    completion: completion
                )
            }
        }
    }

    /// Process authentication on main actor to safely access auth service properties
    @MainActor
    private func processAuthenticationAsync<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping @Sendable (Result<Apollo.GraphQLResult<Operation.Data>, Error>) -> Void
    ) async where Operation: GraphQLOperation & Sendable {
        // Safely access auth service properties on main actor
        guard let authService = authService else {
            Self.logger.warning("⚠️ No authService available in interceptor")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        guard authService.isAuthenticated else {
            Self.logger.debug("🔓 User not authenticated - proceeding without auth headers")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        guard let currentUser = authService.currentAuthUser else {
            Self.logger.warning("⚠️ User is authenticated but no currentAuthUser available")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        Self.logger.debug("🔐 Adding authentication headers")
        Self.logger.debug("📧 User Email: \(currentUser.email)")
        Self.logger.debug("🔑 Auth User ID: \(currentUser.id)")

        // Add auth user ID header
        request.addHeader(name: "X-User-ID", value: currentUser.id)

        // Add authentication token if available
        // Note: Better-Auth primarily uses cookies (now properly configured in URLSession),
        // but we also add the Bearer token for additional security and compatibility
        if let token = getTokenManager()?.loadToken() {
            request.addHeader(name: "Authorization", value: "Bearer \(token.accessToken)")
            Self.logger.debug("🔐 Added Bearer token to request")
        }

        Self.logger.debug("✅ Authentication headers added successfully")

        // Continue with the request chain
        proceedWithChain(chain: chain, request: request, response: response, completion: completion)
    }

    /// Proceed with the chain in a thread-safe manner
    private func proceedWithChain<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping @Sendable (Result<Apollo.GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation {
        // Continue with the request chain using updated API
        chain.proceedAsync(
            request: request,
            response: response,
            interceptor: self,
            completion: completion
        )
    }

    /// Get token manager from auth service (if available)
    @MainActor
    private func getTokenManager() -> AuthTokenManager? {
        // Use the singleton instance from AuthService instead of creating a new one
        return authService?.tokenManager
    }
}

// MARK: - Authentication Error Interceptor

/// Interceptor that detects authentication errors and triggers sign out
private final class AuthErrorInterceptor: ApolloInterceptor, @unchecked Sendable {
    private static let logger = Logger.auth

    let id: String = UUID().uuidString
    private weak var authService: AuthServiceProtocol?

    init(authService: AuthServiceProtocol?) {
        self.authService = authService
    }

    func interceptAsync<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping @Sendable (Result<Apollo.GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation & Sendable {
        // Continue with the chain and check the response
        chain.proceedAsync(
            request: request,
            response: response,
            interceptor: self,
            completion: { [weak self] result in
                self?.checkForAuthenticationError(result: result)
                completion(result)
            }
        )
    }

    private func checkForAuthenticationError<T>(
        result: Result<Apollo.GraphQLResult<T>, Error>
    ) {
        switch result {
        case let .success(graphQLResult):
            // Check GraphQL errors for authentication failures
            if let errors = graphQLResult.errors {
                // Check for authentication errors by message or code
                let hasAuthError = errors.contains { error in
                    // Check the message for "Authentication required"
                    if let message = error.message,
                       message == "Authentication required"
                    {
                        return true
                    }

                    // Also check for error code in extensions as fallback
                    if let extensions = error.extensions,
                       let code = extensions["code"] as? String
                    {
                        return code == "UNAUTHENTICATED" ||
                            code == "UNAUTHORIZED" ||
                            code == "AUTH_ERROR" ||
                            code == "TOKEN_EXPIRED" ||
                            code == "INVALID_TOKEN" ||
                            code == "AUTHENTICATION_REQUIRED" ||
                            code == "FORBIDDEN"
                    }
                    return false
                }

                if hasAuthError {
                    Self.logger.info("🔐 Authentication error detected - signing out user")

                    // Sign out the user on the main actor
                    Task { @MainActor in
                        do {
                            try await self.authService?.signOut()
                            Self.logger.info("✅ User signed out due to authentication error")
                        } catch {
                            Self.logger.error("❌ Failed to sign out after auth error: \(error)")
                        }
                    }
                }
            }
        case .failure:
            // Network errors are handled elsewhere
            break
        }
    }
}

// MARK: - Request Logging Interceptor

/// Interceptor that logs all GraphQL request details including headers
private final class RequestLoggingInterceptor: ApolloInterceptor, @unchecked Sendable {
    private static let logger = Logger.graphql
    nonisolated(unsafe) static var verboseLoggingEnabled = false

    let id: String = UUID().uuidString

    func interceptAsync<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping @Sendable (Result<Apollo.GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation & Sendable {
        // Log request details if verbose logging is enabled
        if Self.verboseLoggingEnabled {
            logRequest(request)
        }

        // Continue with the chain
        chain.proceedAsync(
            request: request,
            response: response,
            interceptor: self,
            completion: { result in
                // Log response details if verbose logging is enabled
                if Self.verboseLoggingEnabled {
                    self.logResponse(result, for: request)
                }
                completion(result)
            }
        )
    }

    private func logHTTPResponse<Operation>(_ response: HTTPResponse<Operation>, for _: HTTPRequest<Operation>) where Operation: GraphQLOperation {
        // ALWAYS log status codes (temporary debugging)
        let httpResponse = response.httpResponse
        Self.logger.info("📥 HTTP Response Status for \(Operation.operationName):")
        Self.logger.info("   Status Code: \(httpResponse.statusCode)")

        // Log additional details if verbose logging is enabled
        if Self.verboseLoggingEnabled {
            Self.logger.info("   Status Description: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            Self.logger.info("   Headers: \(httpResponse.allHeaderFields)")
        }
    }

    private func logRequest<Operation>(_ request: HTTPRequest<Operation>) where Operation: GraphQLOperation {
        guard Self.verboseLoggingEnabled else { return }

        Self.logger.info("📤 GraphQL Request: \(Operation.operationName)")
        Self.logger.info("   URL: \(request.graphQLEndpoint.absoluteString)")

        // Log headers
        Self.logger.info("   Headers:")
        for (key, value) in request.additionalHeaders {
            Self.logger.info("     \(key): \(value)")
        }

        // Log cookies from the URL
        Self.logger.debug("🍪 Checking cookies for URL: \(request.graphQLEndpoint)")

        // First, let's see ALL cookies in the storage
        if let allCookies = HTTPCookieStorage.shared.cookies, !allCookies.isEmpty {
            Self.logger.debug("🍪 All cookies in storage (\(allCookies.count)):")
            for cookie in allCookies {
                Self.logger.debug("   - \(cookie.name) for domain: \(cookie.domain), path: \(cookie.path)")
            }
        } else {
            Self.logger.debug("🍪 No cookies in storage at all!")
        }

        // Now check cookies for the specific URL
        if let cookies = HTTPCookieStorage.shared.cookies(for: request.graphQLEndpoint) {
            if cookies.isEmpty {
                Self.logger.warning("   Cookies: (none) for \(request.graphQLEndpoint)")
            } else {
                Self.logger.info("   Cookies:")
                for cookie in cookies {
                    Self.logger.info("     \(cookie.name): \(cookie.value.prefix(20))... [expires: \(cookie.expiresDate?.description ?? "session")]")
                }
            }
        } else {
            Self.logger.warning("   Cookies: Unable to retrieve cookies for URL: \(request.graphQLEndpoint)")
        }

        // Log the operation name and type
        Self.logger.info("   Operation Name: \(Operation.operationName)")
        Self.logger.info("   Operation Type: \(Operation.operationType)")

        // Note: The actual query string and variables are not easily accessible
        // through the public Apollo API in the interceptor. For debugging GraphQL
        // queries, you can log them at the call site or use Apollo's built-in
        // network logging features.
    }

    private func logResponse<Operation>(_ result: Result<Apollo.GraphQLResult<Operation.Data>, Error>, for _: HTTPRequest<Operation>) where Operation: GraphQLOperation {
        // ALWAYS log errors with their codes (temporary debugging)
        switch result {
        case let .success(graphQLResult):
            if let errors = graphQLResult.errors, !errors.isEmpty {
                Self.logger.warning("⚠️ GraphQL Errors for \(Operation.operationName):")
                for error in errors {
                    var errorInfo = "   - Message: \(error.message ?? "none")"
                    if let extensions = error.extensions {
                        if let code = extensions["code"] as? String {
                            errorInfo += ", Code: \(code)"
                        }
                        // Log any other extension fields for debugging
                        for (key, value) in extensions where key != "code" {
                            errorInfo += ", \(key): \(value)"
                        }
                    }
                    Self.logger.warning(errorInfo)
                }
            }

            // Log success details if verbose logging is enabled
            if Self.verboseLoggingEnabled {
                Self.logger.info("📥 GraphQL Response for \(Operation.operationName): Success")
                if let data = graphQLResult.data {
                    Self.logger.debug("   Data: \(data)")
                }
            }
        case let .failure(error):
            // ALWAYS log failures (temporary debugging)
            Self.logger.error("❌ GraphQL Response for \(Operation.operationName): Failed")
            Self.logger.error("   Error: \(error)")
        }
    }
}

// MARK: - Interceptor Provider

/// Provides interceptors for Apollo Client request chain
private class InterceptorProvider: DefaultInterceptorProvider {
    private let authInterceptor: AuthenticationInterceptor
    private let authErrorInterceptor: AuthErrorInterceptor
    private let loggingInterceptor = RequestLoggingInterceptor()
    private let trimmingInterceptor = StringTrimmingInterceptor()

    init(store: ApolloStore, authInterceptor: AuthenticationInterceptor, authErrorInterceptor: AuthErrorInterceptor, urlSessionClient: URLSessionClient) {
        self.authInterceptor = authInterceptor
        self.authErrorInterceptor = authErrorInterceptor
        super.init(client: urlSessionClient, store: store)
    }

    override func interceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [ApolloInterceptor] {
        var interceptors = super.interceptors(for: operation)

        // Insert interceptors before the network request
        // Find the network fetch interceptor and insert our interceptors before it
        if let networkFetchIndex = interceptors.firstIndex(where: { $0 is NetworkFetchInterceptor }) {
            // Insert in order: trimming → auth → logging → network
            // Trimming goes first to clean data before authentication
            interceptors.insert(trimmingInterceptor, at: networkFetchIndex)
            interceptors.insert(authInterceptor, at: networkFetchIndex + 1)
            interceptors.insert(loggingInterceptor, at: networkFetchIndex + 2)
        } else {
            // Fallback: add at the beginning
            interceptors.insert(trimmingInterceptor, at: 0)
            interceptors.insert(authInterceptor, at: 1)
            interceptors.insert(loggingInterceptor, at: 2)
        }

        // Add the auth error interceptor at the end to check responses
        interceptors.append(authErrorInterceptor)

        return interceptors
    }
}

// MARK: - Error Handling Extension

public extension ApolloClientService {
    /// Handle GraphQL errors in a consistent way
    /// - Parameter error: The error to handle
    /// - Returns: A user-friendly error message
    func handleGraphQLError(_ error: Error) -> String {
        Self.logger.error("🚨 GraphQL Error: \(error)")

        if let graphQLError = error as? GraphQLError {
            return graphQLError.message ?? "GraphQL operation failed"
        } else if error is DecodingError {
            return "Data decoding error occurred"
        } else {
            return "Network error occurred. Please try again."
        }
    }

    /// Log GraphQL operation for debugging
    /// - Parameters:
    ///   - operationName: Name of the GraphQL operation
    ///   - variables: Variables passed to the operation
    func logOperation(
        _ operationName: String,
        variables: Any?
    ) {
        Self.logger.info("📡 GraphQL Operation: \(operationName)")

        if let variables = variables {
            Self.logger.debug("📊 Variables: \(String(describing: variables))")
        }
    }
}
