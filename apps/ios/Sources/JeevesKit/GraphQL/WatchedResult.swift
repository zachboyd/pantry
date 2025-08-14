import Foundation
import Observation

/// Protocol for type-erased watch management
@MainActor
public protocol WatchedResultProtocol: AnyObject {
    func stopWatching()
}

/// Observable wrapper for watched GraphQL query results
@Observable @MainActor
public final class WatchedResult<T: Sendable>: WatchedResultProtocol, Sendable {
    // Current value from the query
    public private(set) var value: T?

    // Loading state
    public private(set) var isLoading: Bool = false

    // Error state
    public private(set) var error: Error?

    // Source of the last update
    public enum DataSource: Sendable {
        case cache
        case server
        case optimistic
    }

    public private(set) var lastSource: DataSource?

    // Timestamp of last update
    public private(set) var lastUpdated: Date?

    // Cleanup handler that's not MainActor-isolated
    private let cleanupHandler: @Sendable () -> Void

    // Unique identifier for this result
    private let id = UUID()

    init(watchManager: WatchManager? = nil) {
        // Create a cleanup handler that captures what we need
        let capturedId = id
        if let watchManager {
            cleanupHandler = { [weak watchManager] in
                Task { @MainActor in
                    watchManager?.stopWatching(id: capturedId)
                }
            }
        } else {
            cleanupHandler = {}
        }
    }

    // Internal update methods (called by WatchManager)
    func update(value: T?, source: DataSource) {
        self.value = value
        lastSource = source
        lastUpdated = Date()
    }

    func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    func setError(_ error: Error?) {
        self.error = error
        if error != nil {
            isLoading = false
        }
    }

    /// Retry a failed query
    public func retry() async {
        guard error != nil else { return }

        setError(nil)
        setLoading(true)

        // Note: Retry functionality would need to be implemented differently
        // since we don't have direct access to the watch manager.
        // This could be handled through a callback or delegate pattern.
    }

    /// Check if error is recoverable
    public var isRecoverableError: Bool {
        guard let error else { return false }

        // Check for common recoverable errors
        let errorString = String(describing: error).lowercased()
        return errorString.contains("network") ||
            errorString.contains("timeout") ||
            errorString.contains("connection") ||
            errorString.contains("retry")
    }

    /// Check if data is stale (older than specified interval)
    public func isStale(olderThan interval: TimeInterval) -> Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > interval
    }

    /// Explicitly stop watching (useful for view onDisappear)
    public func stopWatching() {
        cleanupHandler()
    }

    /// Map the result to a different type
    public func map<U: Sendable>(_ transform: @escaping (T) -> U) -> WatchedResult<U> {
        let mapped = WatchedResult<U>()

        // Copy current state
        mapped.isLoading = isLoading
        mapped.error = error
        // Cannot directly assign lastSource due to different generic types
        if let source = lastSource {
            switch source {
            case .cache:
                mapped.lastSource = .cache
            case .server:
                mapped.lastSource = .server
            case .optimistic:
                mapped.lastSource = .optimistic
            }
        }
        mapped.lastUpdated = lastUpdated

        // Transform value if present
        if let value {
            mapped.value = transform(value)
        }

        return mapped
    }

    /// Convenience computed properties
    public var hasValue: Bool {
        value != nil
    }

    public var hasError: Bool {
        error != nil
    }

    public var isFromCache: Bool {
        lastSource == .cache
    }

    public var isFromServer: Bool {
        lastSource == .server
    }

    // Cleanup on deinit
    deinit {
        // Call the cleanup handler which will handle MainActor properly
        cleanupHandler()
    }
}

// MARK: - Equatable

public extension WatchedResult where T: Equatable {
    @MainActor
    static func == (lhs: WatchedResult<T>, rhs: WatchedResult<T>) -> Bool {
        lhs.value == rhs.value &&
            lhs.isLoading == rhs.isLoading &&
            lhs.lastSource == rhs.lastSource
    }
}

// MARK: - Debug Description

public extension WatchedResult {
    @MainActor
    var debugDescription: String {
        var parts: [String] = []

        if let value {
            parts.append("value: \(value)")
        }

        if isLoading {
            parts.append("loading")
        }

        if let error {
            parts.append("error: \(error)")
        }

        if let source = lastSource {
            parts.append("source: \(source)")
        }

        return "WatchedResult<\(T.self)>(\(parts.joined(separator: ", ")))"
    }
}
