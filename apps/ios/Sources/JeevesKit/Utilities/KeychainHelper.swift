import Foundation
import Security

/// Helper for managing keychain operations
public enum KeychainHelper {
    /// Clear all keychain items for the current app
    /// This only clears items accessible to this app, not the entire keychain
    public static func clearAllKeychainItems() {
        let secClasses = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity,
        ]

        for secClass in secClasses {
            let query: [String: Any] = [
                kSecClass as String: secClass,
            ]

            let status = SecItemDelete(query as CFDictionary)

            if status == errSecSuccess {
                print("✅ Cleared keychain items for class: \(secClass)")
            } else if status == errSecItemNotFound {
                print("ℹ️ No items found for class: \(secClass)")
            } else {
                print("❌ Error clearing keychain for class \(secClass): \(status)")
            }
        }
    }

    /// Clear specific keychain items by service/account
    /// - Parameters:
    ///   - service: The service identifier (e.g., "com.pantry.app")
    ///   - account: The account identifier (optional)
    public static func clearKeychainItem(service: String, account: String? = nil) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        if let account {
            query[kSecAttrAccount as String] = account
        }

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            print("✅ Cleared keychain item for service: \(service)")
        } else if status == errSecItemNotFound {
            print("ℹ️ No keychain item found for service: \(service)")
        } else {
            print("❌ Error clearing keychain item: \(status)")
        }
    }

    /// Clear all HTTP cookies
    /// This removes all cookies from the shared cookie storage
    public static func clearAllCookies() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            print("🍪 Clearing \(cookies.count) cookies")
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
                print("  - Deleted cookie: \(cookie.name) for domain: \(cookie.domain)")
            }
        } else {
            print("ℹ️ No cookies found to clear")
        }
    }

    /// Clear cookies for a specific domain
    /// - Parameter domain: The domain to clear cookies for (e.g., "localhost")
    public static func clearCookies(for domain: String) {
        if let cookies = HTTPCookieStorage.shared.cookies {
            let domainCookies = cookies.filter { cookie in
                cookie.domain == domain || cookie.domain == ".\(domain)"
            }

            print("🍪 Clearing \(domainCookies.count) cookies for domain: \(domain)")
            for cookie in domainCookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
                print("  - Deleted cookie: \(cookie.name)")
            }
        }
    }

    /// Clear all authentication data (keychain + cookies)
    /// This is useful for completely logging out or debugging
    public static func clearAllAuthData() {
        print("🧹 Clearing all authentication data...")

        // Clear keychain items
        clearAllKeychainItems()

        // Clear cookies
        clearAllCookies()

        print("✅ All authentication data cleared")
    }
}
