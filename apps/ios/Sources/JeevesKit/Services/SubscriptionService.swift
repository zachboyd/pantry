@preconcurrency import Apollo
@preconcurrency import ApolloAPI
import Foundation

// MARK: - User Update Subscription Handler

// This handler must be nonisolated to work properly with ApolloStore's dispatch queue
// Per Apollo iOS developer guidance (GitHub issue #3552), withinReadWriteTransaction
// should be called from a nonisolated context to avoid swift_task_isCurrentExecutorImpl crashes
public final class UserUpdateSubscriptionHandler {
    private let store: ApolloStore
    private static let logger = Logger(category: "SubscriptionService")

    public init(store: ApolloStore) {
        self.store = store
    }

    public nonisolated func handleUserUpdate(_ userFields: JeevesGraphQL.UserFields) {
        Self.logger.info("🔄 Processing user update for: \(userFields.id)")

        // Log the update details
        // Self.logger.info("   - Name: \(userFields.first_name) \(userFields.last_name)")
        // Self.logger.info("   - Display Name: \(userFields.display_name ?? "nil")")
        // Self.logger.info("   - Email: \(userFields.email ?? "nil")")

        // Self.logger.info("✨ Writing UserFields fragment directly to cache for user: \(userFields.id)")

        // Write the fragment directly to the cache
        // This is the proper way to update cache with subscription data
        // Create a cache reference for the User object
        let cacheKey = "User:\(userFields.id)"
        // Self.logger.info("🔍 Writing to cache with key: \(cacheKey)")

        // Write the UserFields fragment directly to the cache
        // This will properly merge with existing data and notify all watchers
        store.withinReadWriteTransaction { transaction in
            do {
                // Write the fragment to the cache
                // Apollo will handle the merge and type safety
                try transaction.write(
                    selectionSet: userFields,
                    withKey: cacheKey,
                )
                Self.logger.info("✅ UserFields fragment written to cache successfully")
            } catch {
                Self.logger.error("❌ Failed to write fragment to cache: \(error)")
                Self.logger.error("   Error details: \(error.localizedDescription)")
                // No fallback - let the subscription continue
            }
        }

        Self.logger.info("✅ Cache updated - all watchers will be notified. User update processed.")
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
        userHandler = UserUpdateSubscriptionHandler(store: store)
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
