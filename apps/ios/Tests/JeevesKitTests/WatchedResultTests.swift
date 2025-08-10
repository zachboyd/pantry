@testable import JeevesKit
import XCTest

@MainActor
final class WatchedResultTests: XCTestCase {
    func testInitialState() {
        let result = WatchedResult<String>()

        XCTAssertNil(result.value)
        XCTAssertFalse(result.isLoading)
        XCTAssertNil(result.error)
        XCTAssertNil(result.lastSource)
        XCTAssertNil(result.lastUpdated)
        XCTAssertFalse(result.hasValue)
        XCTAssertFalse(result.hasError)
    }

    func testUpdateValue() {
        let result = WatchedResult<String>()
        let testValue = "Test Value"
        let beforeUpdate = Date()

        result.update(value: testValue, source: .cache)

        let afterUpdate = Date()

        XCTAssertEqual(result.value, testValue)
        XCTAssertEqual(result.lastSource, .cache)
        XCTAssertNotNil(result.lastUpdated)

        if let lastUpdated = result.lastUpdated {
            XCTAssertTrue(lastUpdated >= beforeUpdate)
            XCTAssertTrue(lastUpdated <= afterUpdate)
        }

        XCTAssertTrue(result.hasValue)
        XCTAssertTrue(result.isFromCache)
        XCTAssertFalse(result.isFromServer)
    }

    func testSetLoading() {
        let result = WatchedResult<String>()

        result.setLoading(true)
        XCTAssertTrue(result.isLoading)

        result.setLoading(false)
        XCTAssertFalse(result.isLoading)
    }

    func testSetError() {
        let result = WatchedResult<String>()
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)

        result.setLoading(true)
        result.setError(testError)

        XCTAssertEqual(result.error as? NSError, testError)
        XCTAssertFalse(result.isLoading) // Loading should be false when error is set
        XCTAssertTrue(result.hasError)
    }

    func testClearError() {
        let result = WatchedResult<String>()
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)

        result.setError(testError)
        XCTAssertTrue(result.hasError)

        result.setError(nil)
        XCTAssertFalse(result.hasError)
    }

    func testIsRecoverableError() {
        let result = WatchedResult<String>()

        // Network error should be recoverable
        let networkError = NSError(domain: "Network", code: 1, userInfo: nil)
        result.setError(networkError)
        XCTAssertTrue(result.isRecoverableError)

        // Timeout error should be recoverable
        let timeoutError = NSError(domain: "Timeout", code: 2, userInfo: nil)
        result.setError(timeoutError)
        XCTAssertTrue(result.isRecoverableError)

        // Connection error should be recoverable
        let connectionError = NSError(domain: "Connection", code: 3, userInfo: nil)
        result.setError(connectionError)
        XCTAssertTrue(result.isRecoverableError)

        // Other errors should not be recoverable
        let otherError = NSError(domain: "Other", code: 4, userInfo: nil)
        result.setError(otherError)
        XCTAssertFalse(result.isRecoverableError)

        // No error should not be recoverable
        result.setError(nil)
        XCTAssertFalse(result.isRecoverableError)
    }

    func testIsStale() {
        let result = WatchedResult<String>()

        // No update date should be considered stale
        XCTAssertTrue(result.isStale(olderThan: 60))

        // Fresh update should not be stale
        result.update(value: "test", source: .server)
        XCTAssertFalse(result.isStale(olderThan: 60))

        // Can't test actual staleness without mocking time
        // but we can verify the method exists and works with current data
    }

    func testMap() {
        let result = WatchedResult<Int>()
        result.update(value: 42, source: .server)
        result.setLoading(true)

        let mappedResult = result.map { String($0) }

        XCTAssertEqual(mappedResult.value, "42")
        XCTAssertEqual(mappedResult.lastSource, .server)
        XCTAssertTrue(mappedResult.isLoading)
        XCTAssertNotNil(mappedResult.lastUpdated)
    }

    func testMapWithNilValue() {
        let result = WatchedResult<Int>()
        result.setLoading(true)

        let mappedResult = result.map { String($0) }

        XCTAssertNil(mappedResult.value)
        XCTAssertTrue(mappedResult.isLoading)
    }

    func testMapWithError() {
        let result = WatchedResult<Int>()
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
        result.setError(testError)

        let mappedResult = result.map { String($0) }

        XCTAssertNil(mappedResult.value)
        XCTAssertEqual(mappedResult.error as? NSError, testError)
    }

    func testEquatable() {
        let result1 = WatchedResult<String>()
        let result2 = WatchedResult<String>()

        // Initially equal
        XCTAssertEqual(result1, result2)

        // Update one with value
        result1.update(value: "test", source: .cache)
        XCTAssertNotEqual(result1, result2)

        // Update other with same value
        result2.update(value: "test", source: .cache)
        XCTAssertEqual(result1, result2)

        // Different loading states
        result1.setLoading(true)
        XCTAssertNotEqual(result1, result2)

        result2.setLoading(true)
        XCTAssertEqual(result1, result2)
    }

    func testDebugDescription() {
        let result = WatchedResult<String>()

        // Initial state
        XCTAssertTrue(result.debugDescription.contains("WatchedResult<String>"))

        // With value
        result.update(value: "test", source: .cache)
        XCTAssertTrue(result.debugDescription.contains("value: test"))
        XCTAssertTrue(result.debugDescription.contains("source: cache"))

        // With loading
        result.setLoading(true)
        XCTAssertTrue(result.debugDescription.contains("loading"))

        // With error
        let error = NSError(domain: "Test", code: 1, userInfo: nil)
        result.setError(error)
        XCTAssertTrue(result.debugDescription.contains("error:"))
    }

    func testDataSourceTypes() {
        let result = WatchedResult<String>()

        // Test cache source
        result.update(value: "cached", source: .cache)
        XCTAssertTrue(result.isFromCache)
        XCTAssertFalse(result.isFromServer)

        // Test server source
        result.update(value: "server", source: .server)
        XCTAssertFalse(result.isFromCache)
        XCTAssertTrue(result.isFromServer)

        // Test optimistic source
        result.update(value: "optimistic", source: .optimistic)
        XCTAssertFalse(result.isFromCache)
        XCTAssertFalse(result.isFromServer)
        XCTAssertEqual(result.lastSource, .optimistic)
    }

    func testRetryWithNoError() async {
        let result = WatchedResult<String>()

        // Retry should do nothing if there's no error
        await result.retry()

        XCTAssertFalse(result.isLoading)
        XCTAssertNil(result.error)
    }

    func testRetryWithError() async {
        let result = WatchedResult<String>()
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)

        result.setError(testError)
        XCTAssertNotNil(result.error)

        // Since we don't have a watch manager, retry will clear error and set loading
        // but won't actually retry anything
        await result.retry()

        XCTAssertNil(result.error)
        XCTAssertTrue(result.isLoading)
    }
}
