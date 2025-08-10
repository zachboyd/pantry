import JeevesKit
import SwiftUI

@main
struct JeevesApp: App {
    private static let logger = Logger.app

    // Pre-initialize ThemeManager to ensure theme is loaded before any views render
    private let themeManager: ThemeManager

    init() {
        Self.logger.debug("🚀 APP: JeevesApp init called")
        Self.logger.info("🏁 APP: Starting Jeeves application")

        // Initialize ThemeManager early to load saved theme from UserDefaults
        // This happens before any views are created, preventing flash
        themeManager = ThemeManager.shared
        Self.logger.info("🎨 APP: Theme loaded - \(themeManager.currentTheme)")

        // Apply theme immediately using UIKit for fastest possible application
        // This runs even before the WindowGroup is created
        let manager = themeManager
        DispatchQueue.main.async {
            manager.applyThemeToWindow()
        }

        Self.logger.info("📱 APP: Device ready for launch")
    }

    var body: some Scene {
        let _ = Self.logger.debug("🎯 APP: JeevesApp body called - creating WindowGroup")
        return WindowGroup {
            let _ = Self.logger.debug("🏗️ APP: Creating AppRootView")
            AppRootView()
                .withAppState()
                // Keep SwiftUI modifier as fallback
                .preferredColorScheme(themeManager.colorScheme)
                .task {
                    // Apply theme again once window is available (belt and suspenders)
                    await MainActor.run {
                        themeManager.applyThemeToWindow()
                    }
                }
        }
    }
}
