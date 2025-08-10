import XCTest
@preconcurrency import Apollo
@preconcurrency import ApolloAPI
@testable import JeevesKit
import JeevesGraphQL

// Mock GraphQL Query for testing
private struct MockQuery: GraphQLQuery {
    typealias Data = MockData
    
    let id: String
    
    static var operationName: String { "MockQuery" }
    static var operationType: GraphQLOperationType { .query }
    static var hasDeferredFragments: Bool { false }
    static var document: DocumentType { .notPersisted(definition: .init("query MockQuery { mock }")) }
    
    var __variables: JSONEncodable? {
        ["id": id]
    }
    
    struct MockData: GraphQLSelectionSet {
        static var __parentType: any ParentType { JeevesGraphQL.Objects.Query }
        static var __selections: [Selection] { [] }
        
        let mock: String?
        
        init(mock: String?) {
            self.mock = mock
        }
        
        init(_dataDict: DataDict) {
            self.mock = _dataDict["mock"] as? String
        }
        
        var __data: DataDict {
            DataDict(["mock": mock], fulfilledFragments: [])
        }
    }
}

@MainActor
final class WatchManagerTests: XCTestCase {
    
    var apolloClient: ApolloClient!
    var watchManager: WatchManager!
    var store: ApolloStore!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory cache and store
        let cache = InMemoryNormalizedCache()
        store = ApolloStore(cache: cache)
        
        // Create mock network transport
        let mockTransport = MockNetworkTransport()
        
        // Create Apollo client
        apolloClient = ApolloClient(
            networkTransport: mockTransport,
            store: store
        )
        
        // Create watch manager
        watchManager = WatchManager(apollo: apolloClient)
    }
    
    override func tearDown() async throws {
        watchManager.cancelAllWatchers()
        watchManager = nil
        apolloClient = nil
        store = nil
        try await super.tearDown()
    }
    
    func testInitialState() {
        let debugInfo = watchManager.debugInfo
        
        XCTAssertEqual(debugInfo.activeWatcherCount, 0)
        XCTAssertEqual(debugInfo.totalObserverCount, 0)
        XCTAssertNil(debugInfo.oldestWatcher)
        XCTAssertTrue(debugInfo.watcherDetails.isEmpty)
    }
    
    func testWatchCreatesNewWatcher() {
        let query = MockQuery(id: "1")
        let result = watchManager.watch(query)
        
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isLoading)
        
        let debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1)
        XCTAssertEqual(debugInfo.totalObserverCount, 1)
        XCTAssertNotNil(debugInfo.oldestWatcher)
        XCTAssertEqual(debugInfo.watcherDetails.count, 1)
        XCTAssertEqual(debugInfo.watcherDetails.first?.queryType, "MockQuery")
    }
    
    func testQueryDeduplication() {
        // Create two watches for the same query
        let query1 = MockQuery(id: "1")
        let query2 = MockQuery(id: "1")
        
        let result1 = watchManager.watch(query1)
        let result2 = watchManager.watch(query2)
        
        // Should reuse the same watcher
        let debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1) // Only one watcher
        XCTAssertEqual(debugInfo.totalObserverCount, 2) // Two observers
        XCTAssertEqual(debugInfo.watcherDetails.first?.observerCount, 2)
        
        // Both results should be independent instances
        XCTAssertNotIdentical(result1, result2)
    }
    
    func testDifferentQueriesCreateDifferentWatchers() {
        // Create watches for different queries
        let query1 = MockQuery(id: "1")
        let query2 = MockQuery(id: "2")
        
        let result1 = watchManager.watch(query1)
        let result2 = watchManager.watch(query2)
        
        // Should create different watchers
        let debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 2) // Two watchers
        XCTAssertEqual(debugInfo.totalObserverCount, 2) // Two observers
        
        // Each watcher should have one observer
        for detail in debugInfo.watcherDetails {
            XCTAssertEqual(detail.observerCount, 1)
        }
    }
    
    func testCancelAllWatchers() {
        // Create multiple watchers
        let query1 = MockQuery(id: "1")
        let query2 = MockQuery(id: "2")
        let query3 = MockQuery(id: "1") // Duplicate of query1
        
        _ = watchManager.watch(query1)
        _ = watchManager.watch(query2)
        _ = watchManager.watch(query3)
        
        var debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 2) // Two unique queries
        XCTAssertEqual(debugInfo.totalObserverCount, 3) // Three total observers
        
        // Cancel all watchers
        watchManager.cancelAllWatchers()
        
        debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 0)
        XCTAssertEqual(debugInfo.totalObserverCount, 0)
        XCTAssertNil(debugInfo.oldestWatcher)
        XCTAssertTrue(debugInfo.watcherDetails.isEmpty)
    }
    
    func testCleanupStaleWatchers() {
        // Create a watcher
        let query = MockQuery(id: "1")
        _ = watchManager.watch(query)
        
        var debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1)
        
        // Cleanup with future cutoff (no watchers should be removed)
        watchManager.cleanupStaleWatchers(olderThan: -60) // Negative means future
        
        debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1) // Should still be there
        
        // Cleanup with very old cutoff (all watchers should be kept since they're new)
        watchManager.cleanupStaleWatchers(olderThan: 3600)
        
        debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1) // Should still be there (not stale)
    }
    
    func testDebugInfoDetails() {
        // Create multiple watchers
        let query1 = MockQuery(id: "1")
        let query2 = MockQuery(id: "2")
        
        _ = watchManager.watch(query1)
        _ = watchManager.watch(query2)
        _ = watchManager.watch(query1) // Duplicate
        
        let debugInfo = watchManager.debugInfo
        
        // Verify details
        XCTAssertEqual(debugInfo.watcherDetails.count, 2)
        
        // Find the watcher with 2 observers
        let duplicatedWatcher = debugInfo.watcherDetails.first { $0.observerCount == 2 }
        XCTAssertNotNil(duplicatedWatcher)
        XCTAssertEqual(duplicatedWatcher?.queryType, "MockQuery")
        
        // Find the watcher with 1 observer
        let singleWatcher = debugInfo.watcherDetails.first { $0.observerCount == 1 }
        XCTAssertNotNil(singleWatcher)
        XCTAssertEqual(singleWatcher?.queryType, "MockQuery")
        
        // All watchers should have recent start times
        for detail in debugInfo.watcherDetails {
            let timeSinceStart = Date().timeIntervalSince(detail.startTime)
            XCTAssertLessThan(timeSinceStart, 1.0) // Started less than 1 second ago
        }
    }
    
    func testCachePolicyParameter() {
        let query = MockQuery(id: "1")
        
        // Test with different cache policies
        let result1 = watchManager.watch(query, cachePolicy: .fetchIgnoringCacheData)
        XCTAssertNotNil(result1)
        
        let result2 = watchManager.watch(query, cachePolicy: .returnCacheDataDontFetch)
        XCTAssertNotNil(result2)
        
        // Should still deduplicate even with different cache policies
        // (In real implementation, might want to consider cache policy in deduplication)
        let debugInfo = watchManager.debugInfo
        XCTAssertEqual(debugInfo.activeWatcherCount, 1)
        XCTAssertEqual(debugInfo.totalObserverCount, 2)
    }
}

// MARK: - Mock Network Transport

private final class MockNetworkTransport: NetworkTransport {
    var clientName = "MockTransport"
    var clientVersion = "1.0"
    
    func send<Operation>(
        operation: Operation,
        cachePolicy: CachePolicy,
        contextIdentifier: UUID?,
        context: (any RequestContext)?,
        callbackQueue: DispatchQueue,
        completionHandler: @escaping (Result<GraphQLResult<Operation.Data>, any Error>) -> Void
    ) -> any Cancellable where Operation: GraphQLOperation {
        // Return mock data after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            if let mockOperation = operation as? MockQuery {
                let mockData = MockQuery.MockData(mock: "Mock response for \(mockOperation.id)")
                let result = GraphQLResult(
                    data: mockData as? Operation.Data,
                    extensions: nil,
                    errors: nil,
                    source: .server,
                    dependentKeys: nil
                )
                callbackQueue.async {
                    completionHandler(.success(result))
                }
            } else {
                callbackQueue.async {
                    completionHandler(.failure(NSError(domain: "Mock", code: 1, userInfo: nil)))
                }
            }
        }
        
        return MockCancellable()
    }
}

private final class MockCancellable: Cancellable {
    private var isCancelled = false
    
    func cancel() {
        isCancelled = true
    }
}