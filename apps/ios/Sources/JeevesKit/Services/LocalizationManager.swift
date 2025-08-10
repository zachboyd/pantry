import Foundation
import SwiftUI

/// Observable class that manages app localization and notifies views of language changes
@Observable
@MainActor
public final class LocalizationManager: Sendable {
    private nonisolated(unsafe) static var _shared: LocalizationManager?

    public nonisolated static var shared: LocalizationManager {
        if let existing = _shared {
            return existing
        }
        let instance = MainActor.assumeIsolated {
            LocalizationManager()
        }
        _shared = instance
        return instance
    }

    /// Current app language code
    public private(set) var currentLanguage: String {
        didSet {
            // Save to UserDefaults whenever language changes
            UserDefaults.standard.set(currentLanguage, forKey: "app_language")
        }
    }

    public init() {
        // Initialize with saved language or default to English
        currentLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "en"
    }

    /// Changes the app language and triggers UI updates
    public func setLanguage(_ languageCode: String) {
        guard languageCode != currentLanguage else { return }
        currentLanguage = languageCode
    }

    /// Gets the localized string for the current app language with English fallback
    public func localizedString(for key: String, args: CVarArg...) -> String {
        let bundle = getLocalizedBundle()

        // Use a unique placeholder to detect if translation was found
        let placeholder = "___MISSING_TRANSLATION___"
        let format = NSLocalizedString(key, bundle: bundle, value: placeholder, comment: "")

        var finalFormat = format

        // If translation not found in current language and not already using English, try English fallback
        if format == placeholder && currentLanguage != "en" {
            if let englishPath = Bundle.module.path(forResource: "en", ofType: "lproj"),
               let englishBundle = Bundle(path: englishPath)
            {
                let englishFormat = NSLocalizedString(key, bundle: englishBundle, value: placeholder, comment: "")
                if englishFormat != placeholder {
                    finalFormat = englishFormat
                } else {
                    // If not found in English either, use the key as fallback
                    finalFormat = key
                }
            } else {
                // If English bundle not found, use the key as fallback
                finalFormat = key
            }
        } else if format == placeholder {
            // If using English and still not found, use the key as fallback
            finalFormat = key
        }

        if args.isEmpty {
            return finalFormat
        } else {
            return String(format: finalFormat, arguments: args)
        }
    }

    /// Gets a localized string with plural support using pipe-separated format
    ///
    /// Supports plural strings in the format: "singular|plural"
    /// Example in Localizable.strings: "items.count" = "%d item|%d items"
    ///
    /// - Parameters:
    ///   - key: The localization key
    ///   - count: The count to determine singular (1) or plural (all other values)
    ///   - args: Additional format arguments after the count
    /// - Returns: The formatted localized string with proper plural form
    public func localizedPlural(for key: String, count: Int, args: CVarArg...) -> String {
        let bundle = getLocalizedBundle()

        // Get the format string
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)

        // If translation not found in current language, try English fallback
        var finalFormat = format
        if format == key && currentLanguage != "en" {
            if let englishPath = Bundle.module.path(forResource: "en", ofType: "lproj"),
               let englishBundle = Bundle(path: englishPath)
            {
                let englishFormat = englishBundle.localizedString(forKey: key, value: nil, table: nil)
                if englishFormat != key {
                    finalFormat = englishFormat
                }
            }
        }

        // Check if the format contains pipe separator for plurals
        if finalFormat.contains("|") {
            let parts = finalFormat.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                // Use singular for count == 1, plural otherwise
                let selectedFormat = count == 1 ? parts[0] : parts[1]
                let allArgs = [count] + args
                return String(format: selectedFormat, arguments: allArgs as [CVarArg])
            }
        }

        // If we have a valid format string without pipe, use it as-is
        if finalFormat != key {
            let allArgs = [count] + args
            return String(format: finalFormat, arguments: allArgs as [CVarArg])
        }

        // Fallback to non-plural version
        return localizedString(for: key, args: args)
    }

    /// Gets the appropriate bundle for the current app language
    private func getLocalizedBundle() -> Bundle {
        // Try to get the bundle for the current language
        let language = currentLanguage
        if let path = Bundle.module.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            return bundle
        }

        // Fallback to English if the current language bundle is not found
        if let path = Bundle.module.path(forResource: "en", ofType: "lproj"),
           let bundle = Bundle(path: path)
        {
            return bundle
        }

        // Final fallback to the main module bundle
        return Bundle.module
    }
}
