/*
 ThemeManager+UIKit.swift
 JeevesKit

 UIKit integration for faster theme application
 */

import Foundation
import SwiftUI
import UIKit

public extension ThemeManager {
    /// Apply theme using UIKit's window.overrideUserInterfaceStyle for faster application
    /// This method is ~10x faster than preferredColorScheme modifier
    @MainActor
    func applyThemeToWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        let uiStyle: UIUserInterfaceStyle = switch currentTheme {
        case .system:
            .unspecified
        case .light:
            .light
        case .dark:
            .dark
        }

        // Apply to all windows in the scene including modal presentations
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = uiStyle

            // Also update any presented view controllers (for modals)
            if let rootVC = window.rootViewController {
                updateViewController(rootVC, style: uiStyle)
            }
        }
    }

    /// Recursively update all view controllers including presented ones
    @MainActor
    private func updateViewController(_ viewController: UIViewController, style: UIUserInterfaceStyle) {
        viewController.overrideUserInterfaceStyle = style

        // Update any presented view controllers (modals, sheets, etc.)
        if let presented = viewController.presentedViewController {
            updateViewController(presented, style: style)
        }

        // Update child view controllers
        for child in viewController.children {
            updateViewController(child, style: style)
        }
    }

    /// Apply theme immediately when setting is changed
    @MainActor
    func setUserSavedThemeWithImmediateApplication(_ theme: ThemePreference) {
        setUserSavedTheme(theme)
        applyThemeToWindow()
    }
}
