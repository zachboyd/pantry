import JeevesKit
import SwiftUI

@main
struct JeevesApp: App {
    private static let logger = Logger.app

    init() {
        Self.logger.debug("🚀 APP: JeevesApp init called")
        Self.logger.info("🏁 APP: Starting Jeeves application")
        Self.logger.info("📱 APP: Device ready for launch")
    }

    var body: some Scene {
        let _ = Self.logger.debug("🎯 APP: JeevesApp body called - creating WindowGroup")
        return WindowGroup {
            let _ = Self.logger.debug("🏗️ APP: Creating AppRootView")
            AppRootView()
                .withAppState()
        }
    }
}
