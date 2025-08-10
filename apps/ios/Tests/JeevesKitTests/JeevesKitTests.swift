@testable import JeevesKit
import XCTest

final class JeevesKitTests: XCTestCase {
    func testJeevesKitVersion() throws {
        XCTAssertEqual(JeevesKit.version, "1.0.0")
    }

    @MainActor
    func testAppStateInitialization() async throws {
        let appState = AppState()
        XCTAssertFalse(appState.isInitialized)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.error)

        await appState.initialize()

        XCTAssertTrue(appState.isInitialized)
        XCTAssertFalse(appState.isLoading)
        XCTAssertNil(appState.error)
    }
}
