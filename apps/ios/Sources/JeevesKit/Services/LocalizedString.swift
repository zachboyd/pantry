import Foundation
import SwiftUI

/// Helper function for localized strings in JeevesKit
/// This function uses the LocalizationManager to get translations in the app's selected language
@MainActor
public func L(_ key: String, _ args: CVarArg...) -> String {
    return LocalizationManager.shared.localizedString(for: key, args: args)
}

/// Helper function for localized plural strings
@MainActor
public func Lp(_ key: String, _ count: Int, _ args: CVarArg...) -> String {
    return LocalizationManager.shared.localizedPlural(for: key, count: count, args: args)
}

/// Extension to make localization even more convenient
public extension String {
    /// Returns the localized version of this string
    @MainActor
    var localized: String {
        return L(self)
    }
    
    /// Returns the localized version of this string with arguments
    @MainActor
    func localized(with args: CVarArg...) -> String {
        return L(self, args)
    }
    
    /// Returns the localized plural version of this string
    @MainActor
    func localizedPlural(count: Int, args: CVarArg...) -> String {
        return Lp(self, count, args)
    }
}