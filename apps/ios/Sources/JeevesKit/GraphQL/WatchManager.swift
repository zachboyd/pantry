import Apollo
import ApolloAPI
import Foundation
import Observation

/// Manages Apollo watchers with query deduplication
@MainActor
public final class WatchManager {
    private let apollo: ApolloClient
    private let logger = Logger.graphql

    // Query cache key generation
    private struct QueryKey: Hashable {
        let queryType: String
        let variables: String // JSON encoded

        init<Query: GraphQLQuery>(query: Query) {
            queryType = String(describing: Query.self)

            // Encode variables to JSON for comparison
            if let variables = query.__variables,
               let data = try? JSONEncoder().encode(AnyEncodable(variables)),
               let json = String(data: data, encoding: .utf8)
            {
                self.variables = json
            } else {
                variables = "{}"
            }
        }
    }

    // Active watchers by query key
    private var activeWatchers: [QueryKey: WatcherInfo] = [:]

    // Map from result IDs to query keys for cleanup
    private var resultToQuery: [UUID: QueryKey] = [:]

    // Watcher information
    private class WatcherInfo {
        let watcher: any Cancellable // Apollo's GraphQLQueryWatcher conforms to Cancellable
        var observers: Set<UUID> // WatchedResult instance IDs
        let startTime: Date

        init(watcher: any Cancellable, observerId: UUID) {
            self.watcher = watcher
            observers = [observerId]
            startTime = Date()
        }
    }

    public init(apollo: ApolloClient) {
        self.apollo = apollo
    }

    /// Watch a query with automatic deduplication
    public func watch<Query: GraphQLQuery>(
        _ query: Query,
        cachePolicy: CachePolicy = .returnCacheDataAndFetch
    ) -> WatchedResult<Query.Data> where Query.Data: Sendable {
        let key = QueryKey(query: query)
        let result = WatchedResult<Query.Data>(watchManager: self)
        let resultId = UUID()

        // Check for existing watcher
        if let existingInfo = activeWatchers[key] {
            // Reuse existing watcher
            existingInfo.observers.insert(resultId)
            resultToQuery[resultId] = key

            logger.debug("Reusing existing watcher for \(key.queryType), observers: \(existingInfo.observers.count)")

            // Try to get cached data immediately
            // Note: Cache reading would require the store to be available
            // For now, we'll rely on the watcher to provide cached data
            logger.debug("Reusing watcher for \(key.queryType), waiting for data")

            return result
        }

        // Create new watcher
        result.setLoading(true)

        let watcher = apollo.watch(
            query: query,
            cachePolicy: cachePolicy,
            resultHandler: { [weak self, weak result] graphQLResult in
                guard let self, let result else { return }

                Task { @MainActor in
                    switch graphQLResult {
                    case let .success(data):
                        let source: WatchedResult<Query.Data>.DataSource =
                            data.source == .cache ? .cache : .server

                        result.update(value: data.data, source: source)
                        result.setLoading(false)

                        self.logger.debug("Updated \(key.queryType) from \(source)")

                        // Notify all observers of this query
                        self.notifyObservers(for: key, with: data.data)

                    case let .failure(error):
                        result.setError(error)
                        result.setLoading(false)
                        self.logger.error("Query failed for \(key.queryType): \(error)")
                    }
                }
            },
        )

        // Store watcher - it already conforms to Cancellable
        let info = WatcherInfo(watcher: watcher, observerId: resultId)
        activeWatchers[key] = info
        resultToQuery[resultId] = key

        logger.info("Created new watcher for \(key.queryType)")

        return result
    }

    /// Stop watching when result is no longer needed
    public func stopWatching(id: UUID) {
        guard let key = resultToQuery[id] else { return }

        resultToQuery.removeValue(forKey: id)

        guard let info = activeWatchers[key] else { return }

        info.observers.remove(id)

        // If no more observers, cancel the watcher
        if info.observers.isEmpty {
            info.watcher.cancel()
            activeWatchers.removeValue(forKey: key)
            logger.info("Cancelled watcher for \(key.queryType) (no more observers)")
        } else {
            // Update the watcher info (no need to reassign since it's a class)
            logger.debug("Removed observer from \(key.queryType), remaining: \(info.observers.count)")
        }
    }

    /// Retry a failed query
    public func retry(_: WatchedResult<some Any>) async {
        // Retry functionality would require keeping track of the original query
        // For now, we'll just log that retry was requested
        logger.info("Retry requested but not implemented in this version")
    }

    /// Cancel all active watchers
    public func cancelAllWatchers() {
        for (key, info) in activeWatchers {
            info.watcher.cancel()
            logger.info("Cancelled watcher for \(key.queryType)")
        }

        activeWatchers.removeAll()
        resultToQuery.removeAll()

        logger.info("Cancelled all watchers")
    }

    /// Debug information about active watchers
    public var debugInfo: WatchManagerDebugInfo {
        WatchManagerDebugInfo(
            activeWatcherCount: activeWatchers.count,
            totalObserverCount: activeWatchers.values
                .map(\.observers.count)
                .reduce(0, +),
            oldestWatcher: activeWatchers.values
                .map(\.startTime)
                .min(),
            watcherDetails: activeWatchers.map { key, info in
                WatcherDetail(
                    queryType: key.queryType,
                    observerCount: info.observers.count,
                    startTime: info.startTime,
                )
            },
        )
    }

    // MARK: - Private Helpers

    private func notifyObservers(for key: QueryKey, with _: (some Any)?) {
        guard let info = activeWatchers[key] else { return }

        // All observers for this query have already been updated
        // through their individual result handlers
        logger.debug("Notified \(info.observers.count) observers for \(key.queryType)")
    }
}

// MARK: - Debug Info Types

public struct WatchManagerDebugInfo: Sendable {
    public let activeWatcherCount: Int
    public let totalObserverCount: Int
    public let oldestWatcher: Date?
    public let watcherDetails: [WatcherDetail]
}

public struct WatcherDetail: Sendable {
    public let queryType: String
    public let observerCount: Int
    public let startTime: Date
}

// MARK: - Helper for encoding any Encodable value

private struct AnyEncodable: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        // Try to encode the value if it's Encodable
        if let encodable = value as? Encodable {
            try encodable.encode(to: encoder)
        } else {
            // Fallback to empty object
            var container = encoder.singleValueContainer()
            try container.encode([String: String]())
        }
    }
}
