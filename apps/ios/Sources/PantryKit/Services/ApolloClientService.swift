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
        apollo = Self.createApolloClient(
            endpoint: endpoint,
            authService: authService
        )

        Self.logger.info("✅ Apollo Client service initialized")
    }

    // MARK: - Public Methods

    /// Update the authentication service reference
    /// - Parameter authService: The authentication service
    public func setAuthService(_ authService: AuthServiceProtocol?) {
        self.authService = authService

        // Recreate Apollo Client with new auth service
        apollo = Self.createApolloClient(
            endpoint: graphqlEndpoint,
            authService: authService
        )

        Self.logger.info("🔄 Apollo Client updated with new auth service")
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
        guard authService != nil,
              let token = AuthTokenManager().loadToken() else {
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
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 7) // 7 days
        ])
        
        if let cookie = sessionCookie {
            HTTPCookieStorage.shared.setCookie(cookie)
            Self.logger.info("🍪 Ensured session cookie for GraphQL: \(cookie.name) = \(cookie.value.prefix(20))... for domain: \(domain)")
        }
    }

    // MARK: - Private Methods

    /// Create Apollo Client with proper configuration
    /// - Parameters:
    ///   - endpoint: GraphQL endpoint URL
    ///   - authService: Authentication service for token management
    /// - Returns: Configured Apollo Client
    private static func createApolloClient(
        endpoint: String,
        authService: AuthServiceProtocol?
    ) -> ApolloClient {
        guard let url = URL(string: endpoint) else {
            logger.error("❌ Invalid GraphQL endpoint URL: \(endpoint)")
            fatalError("Invalid GraphQL endpoint URL: \(endpoint)")
        }

        logger.info("🔧 Creating Apollo Client for endpoint: \(endpoint)")

        // Create the cache
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)

        // Create authentication interceptor
        let authInterceptor = AuthenticationInterceptor(authService: authService)

        // Configure URLSession with cookie handling to match AuthClient
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpCookieAcceptPolicy = .always
        sessionConfiguration.httpShouldSetCookies = true
        sessionConfiguration.httpCookieStorage = HTTPCookieStorage.shared
        
        logger.info("🍪 Configured URLSession with cookie support for Better Auth integration")
        
        // Debug: Check if we have any cookies at this point
        if let allCookies = HTTPCookieStorage.shared.cookies {
            logger.info("🍪 Cookies in storage when creating Apollo client: \(allCookies.count)")
            for cookie in allCookies {
                logger.info("   - \(cookie.name) for domain: \(cookie.domain)")
            }
        }
        
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
                urlSessionClient: urlSessionClient
            ),
            endpointURL: url
        )

        // Create Apollo Client
        let client = ApolloClient(
            networkTransport: networkTransport,
            store: store
        )

        logger.info("✅ Apollo Client created successfully with cookie support")
        return client
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
        guard let authService = authService,
              authService.isAuthenticated,
              let currentUser = authService.currentAuthUser
        else {
            Self.logger.debug("🔓 No authentication - proceeding without auth headers")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        Self.logger.debug("🔐 Adding authentication headers for user: \(currentUser.email)")

        // Add user ID header
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
        // This is a simplified approach - in a real implementation,
        // you might want to expose the token manager through the auth service
        return AuthTokenManager()
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
        // Log request details
        logRequest(request)
        
        // Continue with the chain
        chain.proceedAsync(
            request: request,
            response: response,
            interceptor: self,
            completion: { result in
                // Log response details
                self.logResponse(result, for: request)
                completion(result)
            }
        )
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
    
    private func logResponse<Operation>(_ result: Result<Apollo.GraphQLResult<Operation.Data>, Error>, for request: HTTPRequest<Operation>) where Operation: GraphQLOperation {
        guard Self.verboseLoggingEnabled else { return }
        
        switch result {
        case .success(let graphQLResult):
            Self.logger.info("📥 GraphQL Response for \(Operation.operationName): Success")
            if let data = graphQLResult.data {
                Self.logger.debug("   Data: \(data)")
            }
            if let errors = graphQLResult.errors, !errors.isEmpty {
                Self.logger.warning("   Errors: \(errors)")
            }
        case .failure(let error):
            Self.logger.error("📥 GraphQL Response for \(Operation.operationName): Failed")
            Self.logger.error("   Error: \(error)")
        }
    }
}

// MARK: - Interceptor Provider

/// Provides interceptors for Apollo Client request chain
private class InterceptorProvider: DefaultInterceptorProvider {
    private let authInterceptor: AuthenticationInterceptor
    private let loggingInterceptor = RequestLoggingInterceptor()
    private let trimmingInterceptor = StringTrimmingInterceptor()

    init(store: ApolloStore, authInterceptor: AuthenticationInterceptor, urlSessionClient: URLSessionClient) {
        self.authInterceptor = authInterceptor
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
