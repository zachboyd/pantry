import PantryKit
import SwiftUI

@main
struct PantryApp: App {
    private static let logger = Logger.app

    init() {
        Self.logger.debug("🚀 APP: PantryApp init called")
        Self.logger.info("🏁 APP: Starting Pantry application")
        Self.logger.info("📱 APP: Device ready for launch")
    }

    var body: some Scene {
        let _ = Self.logger.debug("🎯 APP: PantryApp body called - creating WindowGroup")
        return WindowGroup {
            let _ = Self.logger.debug("🏗️ APP: Creating AppRootView")
            AppRootView()
                .withAppState()
        }
    }
}
