@testable import PantryKit
import XCTest

final class PantryKitTests: XCTestCase {
    func testPantryKitVersion() throws {
        XCTAssertEqual(PantryKit.version, "1.0.0")
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
