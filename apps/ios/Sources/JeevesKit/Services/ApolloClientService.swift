@preconcurrency import Apollo
@preconcurrency import ApolloAPI
@preconcurrency import ApolloWebSocket
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

    /// WebSocket endpoint URL
    private let webSocketEndpoint: String

    /// WebSocket client for subscriptions
    private var webSocketClient: WebSocket?

    /// WebSocket transport for subscriptions
    private var webSocketTransport: WebSocketTransport?

    /// Split transport combining HTTP and WebSocket
    private var splitTransport: SplitNetworkTransport?

    /// WebSocket connection status
    public private(set) var isWebSocketConnected: Bool = false

    /// Authentication service for token management
    private var authService: (any AuthServiceProtocol)?

    // MARK: - Initialization

    /// Initialize Apollo Client service
    /// - Parameters:
    ///   - endpoint: GraphQL endpoint URL (defaults to localhost:3001/graphql)
    ///   - webSocketEndpoint: WebSocket endpoint URL (defaults to ws://localhost:3001/graphql)
    ///   - authService: Authentication service for token management
    public init(
        endpoint: String = "http://localhost:3001/graphql",
        webSocketEndpoint: String = "ws://localhost:3001/graphql",
        authService: AuthServiceProtocol? = nil
    ) {
        graphqlEndpoint = endpoint
        self.webSocketEndpoint = webSocketEndpoint
        self.authService = authService

        Self.logger.info("🚀 Initializing Apollo Client with WebSocket support")
        Self.logger.info("📡 HTTP endpoint: \(endpoint)")
        Self.logger.info("🔌 WebSocket endpoint: \(webSocketEndpoint)")

        // Create Apollo Client with WebSocket support
        let (client, store, wsClient, wsTransport, split) = Self.createApolloClientWithWebSocket(
            httpEndpoint: endpoint,
            wsEndpoint: webSocketEndpoint,
            authService: authService,
        )
        apollo = client
        self.store = store
        webSocketClient = wsClient
        webSocketTransport = wsTransport
        splitTransport = split

        Self.logger.info("✅ Apollo Client service initialized with WebSocket support")
    }

    // MARK: - Public Methods

    /// Update the auth service after initialization
    /// This recreates the Apollo client to ensure authentication interceptors are properly configured
    public func updateAuthService(_ authService: AuthServiceProtocol?) {
        self.authService = authService

        Self.logger.info("🔄 Updating AuthService in ApolloClientService")
        if let authService {
            Self.logger.info("   - Auth service is authenticated: \(authService.isAuthenticated)")
            Self.logger.info("   - Current auth user: \(authService.currentAuthUser?.email ?? "nil")")
            if let token = authService.tokenManager.loadToken() {
                Self.logger.info("   - Token available: YES")
                Self.logger.info("   - Token value: \(token.accessToken.prefix(20))...")
            } else {
                Self.logger.warning("   - Token available: NO")
            }
        } else {
            Self.logger.warning("   - Auth service is nil")
        }

        // CRITICAL: We must recreate the Apollo Client to ensure the authentication
        // interceptors get the updated authService reference. Otherwise, requests
        // will fail with "Authentication required" even when the user is signed in.
        let (client, store, wsClient, wsTransport, split) = Self.createApolloClientWithWebSocket(
            httpEndpoint: graphqlEndpoint,
            wsEndpoint: webSocketEndpoint,
            authService: authService,
        )
        apollo = client
        self.store = store
        webSocketClient = wsClient
        webSocketTransport = wsTransport
        splitTransport = split

        Self.logger.info("✅ Apollo Client recreated with updated AuthService")
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

    /// Ensure session cookies are available for GraphQL requests
    /// Note: We cannot create signed cookies - they must come from the server
    public func ensureSessionCookies() {
        // Check if we have a properly signed cookie from the server
        let existingCookies = HTTPCookieStorage.shared.cookies ?? []
        let signedSessionCookie = existingCookies.first {
            $0.name == "jeeves.session_token" && $0.value.contains(".")
        }

        if let sessionCookie = signedSessionCookie {
            Self.logger.debug("🍪 Found session cookie: \(sessionCookie.name) for domain: \(sessionCookie.domain)")

            // Ensure cookie is available for GraphQL endpoint
            if let graphQLURL = URL(string: "http://localhost:3001/graphql") {
                // Check if cookie is already available for GraphQL URL
                let graphQLCookies = HTTPCookieStorage.shared.cookies(for: graphQLURL) ?? []
                let hasGraphQLCookie = graphQLCookies.contains { $0.name == "jeeves.session_token" }

                if !hasGraphQLCookie {
                    // Create a new cookie specifically for the GraphQL endpoint
                    var cookieProperties: [HTTPCookiePropertyKey: Any] = [
                        .name: sessionCookie.name,
                        .value: sessionCookie.value,
                        .domain: "localhost",
                        .path: "/",
                        .secure: "FALSE",
                    ]

                    if let expiresDate = sessionCookie.expiresDate {
                        cookieProperties[.expires] = expiresDate
                    }

                    if let graphQLCookie = HTTPCookie(properties: cookieProperties) {
                        HTTPCookieStorage.shared.setCookie(graphQLCookie)
                        Self.logger.info("🍪 Duplicated session cookie for GraphQL endpoint")
                    }
                }
            }
        } else {
            Self.logger.error("❌ No signed session cookie found! Authentication may fail.")
        }
    }

    /// Connect WebSocket for subscriptions
    public func connectWebSocket() async {
        guard !isWebSocketConnected else {
            Self.logger.debug("WebSocket already connected")
            return
        }

        Self.logger.info("🔌 Connecting WebSocket...")
        Self.logger.info("   Client: \(webSocketClient != nil ? "exists" : "nil")")
        Self.logger.info("   Transport: \(webSocketTransport != nil ? "exists" : "nil")")

        // Start the connection
        webSocketClient?.connect()

        // Wait for connection to be established
        // The WebSocket connection takes time to establish and authenticate
        // We need to wait for the connection_init message to be processed
        Self.logger.debug("⏳ Waiting for WebSocket connection to establish...")

        // Wait for the connection to be ready
        // This prevents the race condition where subscriptions are sent before auth is processed
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        isWebSocketConnected = true
        Self.logger.info("✅ WebSocket connected and ready for subscriptions")
    }

    /// Disconnect WebSocket
    public func disconnectWebSocket() {
        guard isWebSocketConnected else { return }

        Self.logger.info("🔌 Disconnecting WebSocket...")
        webSocketClient?.disconnect(forceTimeout: nil)
        isWebSocketConnected = false
        Self.logger.info("✅ WebSocket disconnected")
    }

    /// Reconnect WebSocket with updated authentication
    public func reconnectWebSocket() async {
        Self.logger.info("🔄 Reconnecting WebSocket...")

        // Disconnect existing connection
        disconnectWebSocket()

        // Wait briefly for disconnect to complete
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Reconnect with updated auth
        await connectWebSocket()

        Self.logger.info("✅ WebSocket reconnection complete")
    }

    /// Update WebSocket authentication (requires reconnection)
    public func updateWebSocketAuthentication() async {
        Self.logger.info("🔐 Updating WebSocket authentication")

        // WebSocket authentication updates require reconnection
        // We'll need to recreate the transport with new auth payload
        let (newClient, newStore, wsClient, wsTransport, split) = Self.createApolloClientWithWebSocket(
            httpEndpoint: graphqlEndpoint,
            wsEndpoint: webSocketEndpoint,
            authService: authService,
        )

        // Update Apollo client and WebSocket references
        apollo = newClient
        store = newStore
        webSocketClient = wsClient
        webSocketTransport = wsTransport
        splitTransport = split

        Self.logger.info("✅ WebSocket authentication updated")
    }

    // MARK: - Private Methods

    /// Create WebSocket authentication payload
    private static func createWebSocketAuthPayload(
        authService _: AuthServiceProtocol?,
    ) -> JSONEncodableDictionary? {
        // The server expects cookies to be passed in connectionParams
        // This is required because the WebSocket connection doesn't maintain
        // the HTTP cookie context after the upgrade

        var payload: JSONEncodableDictionary = [:]

        // Find the SIGNED session cookie (contains a "." character)
        // The cookie must be the full signed value from the server, not just the session ID
        if let cookies = HTTPCookieStorage.shared.cookies {
            // Look for the signed cookie - it should contain a "." from the signature
            let sessionCookie = cookies.first {
                $0.name == "jeeves.session_token" && $0.value.contains(".")
            }

            if let cookie = sessionCookie {
                // IMPORTANT: Better-auth might expect the cookie value as-is
                // Try sending the raw cookie value without any decoding first
                let rawValue = cookie.value

                // Also prepare a decoded version for comparison
                let decodedValue = cookie.value
                    .replacingOccurrences(of: "%2B", with: "+")
                    .replacingOccurrences(of: "%3D", with: "=")
                    .replacingOccurrences(of: "%2F", with: "/")
                    .replacingOccurrences(of: "%20", with: " ")
                    .replacingOccurrences(of: "%2D", with: "-")
                    .replacingOccurrences(of: "%5F", with: "_")
                    .replacingOccurrences(of: "%2E", with: ".")
                    .replacingOccurrences(of: "%7E", with: "~")

                // CRITICAL INSIGHT: HTTP requests send the RAW cookie value and they WORK!
                // The HTTP interceptor does: "\(cookie.name)=\(cookie.value)"
                // Let's use the SAME format for WebSocket
                let cookieString = "\(cookie.name)=\(rawValue)"
                payload["cookie"] = cookieString

                // Log for debugging
                logger.info("🔐 Cookie for connection_init:")
                logger.info("   Name: \(cookie.name)")
                logger.info("   Raw (stored): \(rawValue.prefix(50))...")
                logger.info("   Decoded: \(decodedValue.prefix(50))...")
                logger.info("   Using: RAW value (same as working HTTP requests)")
                logger.info("   Has signature: \(decodedValue.contains("."))")
                logger.info("   Full cookie string length: \(cookieString.count)")
            } else {
                // Check if we have an unsigned cookie (shouldn't happen)
                if let unsignedCookie = cookies.first(where: { $0.name == "jeeves.session_token" }) {
                    logger.warning("⚠️ Found unsigned session cookie: \(unsignedCookie.value)")
                    logger.warning("⚠️ This won't work for authentication - need signed cookie from server")
                } else {
                    logger.warning("⚠️ No session cookie in storage for connection_init")
                }
            }
        }

        logger.info("🔐 WebSocket auth payload keys: \(payload.keys.joined(separator: ", "))")

        // Log the actual payload for debugging
        if let cookieValue = payload["cookie"] as? String {
            logger.info("📦 connection_init payload will contain:")
            logger.info("   cookie: \(cookieValue.prefix(100))...")
        }

        return payload.isEmpty ? nil : payload
    }

    /// Create Apollo Client with WebSocket support
    /// - Parameters:
    ///   - httpEndpoint: HTTP GraphQL endpoint URL
    ///   - wsEndpoint: WebSocket GraphQL endpoint URL
    ///   - authService: Authentication service for token management
    /// - Returns: Tuple of configured Apollo Client and ApolloStore
    private static func createApolloClientWithWebSocket(
        httpEndpoint: String,
        wsEndpoint: String,
        authService: AuthServiceProtocol?,
    ) -> (ApolloClient, ApolloStore, WebSocket, WebSocketTransport, SplitNetworkTransport) {
        guard let httpURL = URL(string: httpEndpoint),
              let wsURL = URL(string: wsEndpoint)
        else {
            logger.error("❌ Invalid GraphQL endpoints")
            fatalError("Invalid GraphQL endpoints")
        }

        logger.info("🔧 Creating Apollo Client with WebSocket support")
        logger.info("📡 HTTP endpoint: \(httpEndpoint)")
        logger.info("🌐 WebSocket endpoint: \(wsEndpoint)")

        // Create cache and store
        let cache = InMemoryNormalizedCache()
        let store = ApolloStore(cache: cache)

        // Create authentication interceptors
        let authInterceptor = AuthenticationInterceptor(authService: authService)
        let authErrorInterceptor = AuthErrorInterceptor(authService: authService)

        // Configure URLSession for HTTP transport
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpCookieStorage = HTTPCookieStorage.shared
        sessionConfig.httpCookieAcceptPolicy = .always
        sessionConfig.httpShouldSetCookies = true

        let urlSessionClient = URLSessionClient(
            sessionConfiguration: sessionConfig,
            callbackQueue: nil,
        )

        // Create HTTP transport with interceptors
        let httpTransport = RequestChainNetworkTransport(
            interceptorProvider: InterceptorProvider(
                store: store,
                authInterceptor: authInterceptor,
                authErrorInterceptor: authErrorInterceptor,
                urlSessionClient: urlSessionClient,
            ),
            endpointURL: httpURL,
        )

        // Ensure session cookies are available for GraphQL endpoint before WebSocket creation
        // This is a static method, so we need to ensure cookies manually
        if let existingCookies = HTTPCookieStorage.shared.cookies,
           let sessionCookie = existingCookies.first(where: { $0.name == "jeeves.session_token" && $0.value.contains(".") })
        {
            logger.debug("🍪 Found session cookie, ensuring it's available for GraphQL")

            // Ensure cookie is available for both HTTP and WebSocket URLs
            let graphQLCookies = HTTPCookieStorage.shared.cookies(for: httpURL) ?? []
            if !graphQLCookies.contains(where: { $0.name == "jeeves.session_token" }) {
                var cookieProperties: [HTTPCookiePropertyKey: Any] = [
                    .name: sessionCookie.name,
                    .value: sessionCookie.value,
                    .domain: httpURL.host ?? "localhost",
                    .path: "/",
                    .secure: "FALSE",
                ]

                if let expiresDate = sessionCookie.expiresDate {
                    cookieProperties[.expires] = expiresDate
                }

                if let graphQLCookie = HTTPCookie(properties: cookieProperties) {
                    HTTPCookieStorage.shared.setCookie(graphQLCookie)
                    logger.info("🍪 Made session cookie available for GraphQL endpoint")
                }
            }
        }

        // Create WebSocket client
        // IMPORTANT: For graphql-ws protocol, authentication is handled through
        // the connectingPayload in the connection_init message, NOT through HTTP headers
        let wsRequest = URLRequest(url: wsURL)

        logger.info("🔍 WebSocket URLRequest details:")
        logger.info("   URL: \(wsRequest.url?.absoluteString ?? "nil")")
        logger.info("   Protocol: graphql-transport-ws (graphql-ws v6+)")

        let authPayload = createWebSocketAuthPayload(authService: authService)

        // Log the full auth payload for debugging
        if let payload = authPayload {
            logger.info("📤 Full connection_init payload:")
            for (key, value) in payload {
                if let stringValue = value as? String {
                    logger.info("   \(key): \(stringValue)")
                } else {
                    logger.info("   \(key): \(value)")
                }
            }
        } else {
            logger.warning("⚠️ No auth payload for WebSocket connection_init")
        }

        // Use graphql_transport_ws which actually maps to "graphql-ws" protocol string
        // The naming is confusing: .graphql_transport_ws = "graphql-ws" (v6+)
        //                          .graphql_ws = "graphql-ws" (older/legacy)
        // Since backend uses graphql-ws@6.0.4, we need the transport version
        let webSocketClient = WebSocket(
            request: wsRequest,
            protocol: .graphql_transport_ws,
        )

        // Configure WebSocket transport
        // IMPORTANT: The connectingPayload is sent as the connection_init message
        // after the WebSocket connection is established. The server uses this to
        // authenticate the subscription at the GraphQL protocol level, not just
        // the HTTP upgrade level.
        let webSocketTransport = WebSocketTransport(
            websocket: webSocketClient,
            config: WebSocketTransport.Configuration(
                reconnect: true,
                reconnectionInterval: 0.5,
                allowSendingDuplicates: true,
                connectingPayload: authPayload,
                requestBodyCreator: ApolloRequestBodyCreator(),
            ),
        )

        // Create split transport
        let splitTransport = SplitNetworkTransport(
            uploadingNetworkTransport: httpTransport,
            webSocketNetworkTransport: webSocketTransport,
        )

        // Create Apollo client
        let client = ApolloClient(
            networkTransport: splitTransport,
            store: store,
        )

        logger.info("✅ Apollo Client created with split HTTP/WebSocket transport")
        return (client, store, webSocketClient, webSocketTransport, splitTransport)
    }

    /// Create Apollo Client with proper configuration (legacy HTTP-only)
    /// - Parameters:
    ///   - endpoint: GraphQL endpoint URL
    ///   - authService: Authentication service for token management
    /// - Returns: Tuple of configured Apollo Client and ApolloStore
    private static func createApolloClient(
        endpoint: String,
        authService: AuthServiceProtocol?,
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
            callbackQueue: nil,
        )

        // Create network transport with interceptors and custom URLSessionClient
        let networkTransport = RequestChainNetworkTransport(
            interceptorProvider: InterceptorProvider(
                store: store,
                authInterceptor: authInterceptor,
                authErrorInterceptor: authErrorInterceptor,
                urlSessionClient: urlSessionClient,
            ),
            endpointURL: url,
        )

        // Create Apollo Client with cache normalization
        // Note: In Apollo iOS 1.x, cache key normalization is handled by the store
        // The default behavior uses the 'id' field as the cache key when available
        let client = ApolloClient(
            networkTransport: networkTransport,
            store: store,
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
            guard let self else {
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
                    completion: completion,
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
        guard let authService else {
            Self.logger.warning("⚠️ No authService available in interceptor")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        guard authService.isAuthenticated else {
            Self.logger.debug("🔓 User not authenticated - proceeding without auth headers")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        guard let currentAuthUser = authService.currentAuthUser else {
            Self.logger.warning("⚠️ User is authenticated but no currentAuthUser available")
            proceedWithChain(chain: chain, request: request, response: response, completion: completion)
            return
        }

        Self.logger.debug("🔐 Adding authentication headers")
        Self.logger.debug("📧 User Email: \(currentAuthUser.email)")
        Self.logger.debug("🔑 Auth User ID: \(currentAuthUser.id)")

        // WORKAROUND: Manually add Cookie header since automatic cookie handling seems broken
        // Find the actual signed session cookie from HTTPCookieStorage
        if let cookies = HTTPCookieStorage.shared.cookies {
            let sessionCookie = cookies.first {
                $0.name == "jeeves.session_token" && $0.value.contains(".")
            }

            if let cookie = sessionCookie {
                let cookieHeader = "\(cookie.name)=\(cookie.value)"
                request.addHeader(name: "Cookie", value: cookieHeader)
            }
        }

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
            completion: completion,
        )
    }

    /// Get token manager from auth service (if available)
    @MainActor
    private func getTokenManager() -> AuthTokenManager? {
        // Use the singleton instance from AuthService instead of creating a new one
        authService?.tokenManager
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
            },
        )
    }

    private func checkForAuthenticationError(
        result: Result<Apollo.GraphQLResult<some Any>, Error>,
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
            },
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

    override func interceptors(
        for operation: some GraphQLOperation,
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
        variables: Any?,
    ) {
        Self.logger.info("📡 GraphQL Operation: \(operationName)")

        if let variables {
            Self.logger.debug("📊 Variables: \(String(describing: variables))")
        }
    }
}
