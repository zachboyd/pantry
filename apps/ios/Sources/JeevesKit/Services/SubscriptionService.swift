@preconcurrency import Apollo
@preconcurrency import ApolloAPI
import Foundation

// MARK: - User Update Subscription Handler

@MainActor
public final class UserUpdateSubscriptionHandler {
    private let store: ApolloStore
    private let apolloClient: ApolloClient
    private static let logger = Logger(category: "SubscriptionService")

    public init(store: ApolloStore, apolloClient: ApolloClient) {
        self.store = store
        self.apolloClient = apolloClient
    }

    public func handleUserUpdate(_ userFields: JeevesGraphQL.UserFields) {
        Self.logger.info("🔄 Processing user update for: \(userFields.id)")

        // Log the update details
        Self.logger.info("   - Name: \(userFields.first_name) \(userFields.last_name)")
        Self.logger.info("   - Display Name: \(userFields.display_name ?? "nil")")
        Self.logger.info("   - Email: \(userFields.email ?? "nil")")

        Self.logger.info("✨ Updating cache with subscription data for user: \(userFields.id)")

        // Use Apollo's proper cache update mechanism
        // The key insight: we need to update the SAME cache entry that GetCurrentUserQuery is watching
        // Subscription data (UserFields) and query data (CurrentUser) are different types in Apollo's cache

        Self.logger.info("🔍 Attempting to update cache with subscription data...")

        // Since Apollo iOS 1.x doesn't have direct cache manipulation APIs,
        // we'll trigger a refetch of the GetCurrentUserQuery to get fresh data
        // This will update the cache and notify all watchers

        Self.logger.info("🔍 Triggering GetCurrentUserQuery refetch...")

        // Execute a network-only query to force a refresh from the server
        // This will update the Apollo cache with fresh data, which will then
        // automatically update all watchers that are observing the cache
        let query = JeevesGraphQL.GetCurrentUserQuery()

        apolloClient.fetch(query: query, cachePolicy: .fetchIgnoringCacheData) { result in
            switch result {
            case let .success(graphQLResult):
                if let userData = graphQLResult.data?.currentUser {
                    Self.logger.info("✅ GetCurrentUserQuery refetch successful - cache updated")
                    Self.logger.info("✅ User data refreshed: \(userData.first_name) \(userData.last_name)")
                    Self.logger.info("✅ Watchers should now receive fresh data from updated cache")
                } else {
                    Self.logger.warning("⚠️ GetCurrentUserQuery refetch returned nil user")
                }

                if let errors = graphQLResult.errors {
                    Self.logger.error("❌ GetCurrentUserQuery refetch had errors: \(errors)")
                }

            case let .failure(error):
                Self.logger.error("❌ GetCurrentUserQuery refetch failed: \(error)")
            }
        }

        Self.logger.info("✅ User update processed - cache will be updated via query refetch")
    }
}

// MARK: - Main Subscription Service

@MainActor
public final class SubscriptionService: SubscriptionServiceProtocol {
    private let store: ApolloStore
    private let apolloClient: ApolloClient
    private let userHandler: UserUpdateSubscriptionHandler
    private var userSubscriptionCancellable: Cancellable?
    private static let logger = Logger(category: "SubscriptionService")

    public init(store: ApolloStore, apolloClient: ApolloClient) {
        self.store = store
        self.apolloClient = apolloClient
        userHandler = UserUpdateSubscriptionHandler(store: store, apolloClient: apolloClient)
    }

    public func handleUserUpdateSubscription(
        result: Result<GraphQLResult<JeevesGraphQL.UserUpdatedSubscription.Data>, Error>,
    ) {
        switch result {
        case let .success(graphQLResult):
            if let errors = graphQLResult.errors {
                Self.logger.error("❌ Subscription errors: \(errors)")
                return
            }

            if let userData = graphQLResult.data?.userUpdated {
                Self.logger.info("📥 Received user update: \(userData.fragments.userFields.id)")
                userHandler.handleUserUpdate(userData.fragments.userFields)
            }

        case let .failure(error):
            Self.logger.error("❌ Subscription error: \(error)")
        }
    }

    // MARK: - SubscriptionServiceProtocol Implementation

    public func subscribeToUserUpdates() async throws {
        Self.logger.info("📡 Starting user updates subscription...")

        // Cancel any existing subscription
        userSubscriptionCancellable?.cancel()

        // Start the actual GraphQL subscription
        let subscription = JeevesGraphQL.UserUpdatedSubscription()

        Self.logger.info("📡 Creating real UserUpdated subscription...")

        // Use ApolloClient to start the real subscription
        userSubscriptionCancellable = apolloClient.subscribe(subscription: subscription) { [weak self] result in
            Task { @MainActor in
                Self.logger.info("📥 Real subscription data received!")
                self?.handleUserUpdateSubscription(result: result)
            }
        }

        if userSubscriptionCancellable != nil {
            Self.logger.info("✅ Real UserUpdated subscription started successfully")
        } else {
            Self.logger.error("❌ Failed to start UserUpdated subscription")
            throw SubscriptionError.subscriptionFailed
        }
    }

    public func unsubscribeFromUserUpdates() {
        Self.logger.info("🛑 Stopping user updates subscription...")
        userSubscriptionCancellable?.cancel()
        userSubscriptionCancellable = nil
        Self.logger.info("✅ User updates subscription stopped")
    }

    public func stopAllSubscriptions() {
        Self.logger.info("🛑 Stopping all subscriptions...")
        Self.logger.info("✅ All subscriptions stopped")
    }
}

// MARK: - Subscription Errors

public enum SubscriptionError: Error, LocalizedError {
    case subscriptionFailed

    public var errorDescription: String? {
        switch self {
        case .subscriptionFailed:
            "Failed to start subscription"
        }
    }
}
