@preconcurrency import Apollo
@preconcurrency import ApolloAPI
import Foundation

// MARK: - User Update Handler

// This handler must be nonisolated to work properly with ApolloStore's dispatch queue
// Per Apollo iOS developer guidance (GitHub issue #3552), withinReadWriteTransaction
// should be called from a nonisolated context to avoid swift_task_isCurrentExecutorImpl crashes
public final class UserUpdateHandler {
    private let store: ApolloStore
    private static let logger = Logger(category: "SubscriptionService")

    public init(store: ApolloStore) {
        self.store = store
    }

    public nonisolated func updateCache(with userFields: JeevesGraphQL.UserFields) {
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
    private let userUpdateHandler: UserUpdateHandler
    private var userSubscriptionCancellable: Cancellable?
    private static let logger = Logger(category: "SubscriptionService")

    public init(store: ApolloStore, apolloClient: ApolloClient) {
        self.store = store
        self.apolloClient = apolloClient
        userUpdateHandler = UserUpdateHandler(store: store)
    }

    // MARK: - Generic Subscription Result Handling

    /// Generic handler for all subscription results with common error handling
    /// - Parameters:
    ///   - result: The subscription result from Apollo
    ///   - subscriptionName: Name of the subscription for logging
    ///   - dataHandler: Closure to handle valid data
    private func processSubscriptionResult<T>(
        _ result: Result<GraphQLResult<T>, Error>,
        subscriptionName: String,
        dataHandler: (T) -> Void
    ) {
        switch result {
        case let .success(graphQLResult):
            // Common error handling for all subscriptions
            if let errors = graphQLResult.errors {
                Self.logger.error("❌ \(subscriptionName) GraphQL errors: \(errors)")
                return
            }

            // Call specific handler only if data exists
            if let data = graphQLResult.data {
                dataHandler(data)
            } else {
                Self.logger.info("📭 \(subscriptionName) result with no data")
            }

        case let .failure(error):
            Self.logger.error("❌ \(subscriptionName) connection error: \(error)")
        }
    }

    // MARK: - Specific Subscription Handlers

    /// Handles UserUpdated subscription results
    /// This method now only deals with valid UserUpdated data
    private func processUserUpdate(_ data: JeevesGraphQL.UserUpdatedSubscription.Data) {
        let userData = data.userUpdated
        Self.logger.info("📥 Received user update: \(userData.fragments.userFields.id)")
        userUpdateHandler.updateCache(with: userData.fragments.userFields)
    }

    // NOTE: Future subscription handlers will follow the same pattern:
    // - Create a specific data processing method (e.g., processHouseholdUpdate)
    // - Create a specific handler class if needed (e.g., HouseholdUpdateHandler)
    // - Use processSubscriptionResult for consistent error handling
    // Example:
    // private func processHouseholdUpdate(_ data: JeevesGraphQL.HouseholdUpdatedSubscription.Data) {
    //     let householdData = data.householdUpdated
    //     householdUpdateHandler.updateCache(with: householdData.fragments.householdFields)
    // }

    /// Public method for compatibility with existing subscription setup
    public func didReceiveUserUpdateResult(
        result: Result<GraphQLResult<JeevesGraphQL.UserUpdatedSubscription.Data>, Error>,
    ) {
        processSubscriptionResult(
            result,
            subscriptionName: "UserUpdated",
            dataHandler: processUserUpdate,
        )
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
                self?.didReceiveUserUpdateResult(result: result)
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
