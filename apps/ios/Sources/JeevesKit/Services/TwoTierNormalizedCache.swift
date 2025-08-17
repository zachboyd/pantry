import Apollo
import ApolloAPI
import ApolloSQLite
import Foundation
import UIKit

/// A two-tier cache implementation that uses in-memory cache as primary
/// and SQLite cache as a persistence layer
///
/// This provides the speed benefits of in-memory caching with the
/// persistence benefits of SQLite storage.
///
/// Note: Marked as @unchecked Sendable because it contains non-Sendable types (caches)
/// but all access is synchronized through Apollo's internal locking mechanisms.
public final class TwoTierNormalizedCache: NormalizedCache, @unchecked Sendable {
    private let memoryCache: InMemoryNormalizedCache
    private let sqliteCache: SQLiteNormalizedCache
    private let logger = Logger.graphql

    /// Initialize with an existing SQLite cache
    /// The memory cache will be populated from SQLite on first access
    public init(sqliteCache: SQLiteNormalizedCache) {
        self.sqliteCache = sqliteCache
        memoryCache = InMemoryNormalizedCache()

        logger.info("🎯 Initialized two-tier cache (Memory + SQLite)")
    }

    /// Convenience initializer to create both caches
    public convenience init(fileURL: URL, shouldVacuumOnClear: Bool = true) throws {
        let sqlite = try SQLiteNormalizedCache(
            fileURL: fileURL,
            shouldVacuumOnClear: shouldVacuumOnClear,
        )
        self.init(sqliteCache: sqlite)
    }

    // MARK: - NormalizedCache Protocol

    public func loadRecords(forKeys keys: Set<CacheKey>) throws -> [CacheKey: Record] {
        // First, try to load from memory cache (fast path)
        let memoryRecords = try memoryCache.loadRecords(forKeys: keys)

        // Find keys that weren't in memory
        let missingKeys = keys.filter { memoryRecords[$0] == nil }

        // If all keys were found in memory, return immediately
        if missingKeys.isEmpty {
            logger.debug("✅ All \(keys.count) keys found in memory cache")
            return memoryRecords
        }

        // Load missing keys from SQLite (slow path)
        logger.info("🔍 Loading \(missingKeys.count) missing keys from SQLite")
        let sqliteRecords = try sqliteCache.loadRecords(forKeys: Set(missingKeys))

        // Store SQLite records in memory for future access
        if !sqliteRecords.isEmpty {
            let recordSet = RecordSet(records: sqliteRecords.map(\.value))
            _ = try memoryCache.merge(records: recordSet)
            logger.debug("📝 Cached \(sqliteRecords.count) records from SQLite to memory")
        }

        // Combine results from both caches
        var combinedRecords = memoryRecords
        for (key, record) in sqliteRecords {
            combinedRecords[key] = record
        }

        return combinedRecords
    }

    public func merge(records: RecordSet) throws -> Set<CacheKey> {
        // Write to both caches - memory first for immediate availability
        let memKeys = try memoryCache.merge(records: records)
        let sqlKeys = try sqliteCache.merge(records: records)

        logger.debug("💾 Merged records - Memory: \(memKeys.count) keys, SQLite: \(sqlKeys.count) keys")

        // Return the union of modified keys from both caches
        return memKeys.union(sqlKeys)
    }

    public func removeRecord(for key: CacheKey) throws {
        // Remove from both caches
        try memoryCache.removeRecord(for: key)
        try sqliteCache.removeRecord(for: key)

        logger.debug("🗑️ Removed record for key: \(key)")
    }

    public func removeRecords(matching pattern: CacheKey) throws {
        // Remove from both caches
        try memoryCache.removeRecords(matching: pattern)
        try sqliteCache.removeRecords(matching: pattern)

        logger.debug("🗑️ Removed records matching pattern: \(pattern)")
    }

    public func clear() throws {
        // Clear both caches
        // Note: clear() doesn't throw for InMemoryNormalizedCache
        memoryCache.clear()
        try sqliteCache.clear()

        logger.info("🧹 Cleared both memory and SQLite caches")
    }

    // MARK: - Memory Management

    /// Clear only the memory cache to free up RAM
    /// SQLite cache remains intact for persistence
    public func clearMemoryCache() {
        memoryCache.clear()
        logger.info("🧹 Cleared memory cache only (SQLite preserved)")
    }

    /// Preload specific keys into memory cache from SQLite
    /// Useful for warming up the cache with frequently accessed data
    public func preloadIntoMemory(keys: Set<CacheKey>) throws {
        let sqliteRecords = try sqliteCache.loadRecords(forKeys: keys)

        if !sqliteRecords.isEmpty {
            let recordSet = RecordSet(records: sqliteRecords.map(\.value))
            _ = try memoryCache.merge(records: recordSet)
            logger.info("📥 Preloaded \(sqliteRecords.count) records into memory cache")
        }
    }

    /// Get memory usage statistics for monitoring
    public func getCacheStatistics() throws -> CacheStatistics {
        // Get approximate count by loading all records (be careful with large caches)
        // In a real implementation, you'd want a more efficient way to count records
        let memoryRecords = try memoryCache.loadRecords(forKeys: Set())

        return CacheStatistics(
            memoryRecordCount: memoryRecords.count,
            estimatedMemorySize: memoryRecords.count * 1024, // Rough estimate
        )
    }
}

// MARK: - Supporting Types

public struct CacheStatistics {
    public let memoryRecordCount: Int
    public let estimatedMemorySize: Int // in bytes

    public var formattedMemorySize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(estimatedMemorySize))
    }
}

// MARK: - Memory Pressure Handling

extension TwoTierNormalizedCache {
    /// Register for memory warnings to automatically clear memory cache
    public func registerForMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        logger.warning("⚠️ Memory warning received - clearing memory cache")
        clearMemoryCache()
    }
}
