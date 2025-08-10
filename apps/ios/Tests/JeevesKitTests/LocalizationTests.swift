@testable import JeevesKit
import XCTest

@MainActor
final class LocalizationTests: XCTestCase {
    func testLocalizationManagerSingleton() async {
        let manager1 = LocalizationManager.shared
        let manager2 = LocalizationManager.shared

        // Test singleton pattern
        XCTAssertTrue(manager1 === manager2, "LocalizationManager should be a singleton")
    }

    func testLocalizedStringFunction() async {
        // Test basic localization
        let appName = L("app.name")
        XCTAssertEqual(appName, "Jeeves", "App name should be localized correctly")

        // Test missing key fallback
        let missingKey = L("missing.key.test")
        XCTAssertEqual(missingKey, "missing.key.test", "Missing keys should return the key itself")
    }

    func testLanguageSwitching() async {
        let manager = LocalizationManager.shared

        // Test initial language
        XCTAssertEqual(manager.currentLanguage, "en", "Default language should be English")

        // Test language switching
        manager.setLanguage("es")
        XCTAssertEqual(manager.currentLanguage, "es", "Language should be changed to Spanish")

        // Reset to English
        manager.setLanguage("en")
        XCTAssertEqual(manager.currentLanguage, "en", "Language should be changed back to English")
    }

    func testStringExtensions() async {
        // Test string extension
        let title = "app.name".localized
        XCTAssertEqual(title, "Jeeves", "String extension should work correctly")
    }
}
