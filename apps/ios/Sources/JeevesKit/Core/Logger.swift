import Foundation
import os.log

/// Unified logging framework for Jeeves
/// Provides consistent logging with appropriate levels and subsystems
public struct Logger: Sendable {
    private let subsystem = "com.jeevesapp.app"
    private let category: String
    private let logger: os.Logger

    public init(category: String) {
        self.category = category
        logger = os.Logger(subsystem: subsystem, category: category)
    }

    // MARK: - Logging Methods

    /// Debug information for development
    public func debug(_ message: String, file _: String = #file, function _: String = #function, line _: Int = #line) {
        #if DEBUG
            logger.debug("🔍 [\(category)] \(message)")
        #endif
    }

    /// General information
    public func info(_ message: String) {
        let formattedMessage = "ℹ️ [\(category)] \(message)"
        logger.info("\(formattedMessage)")
        #if DEBUG
            print(formattedMessage)
        #endif
    }

    /// Warnings that don't prevent operation
    public func warning(_ message: String) {
        let formattedMessage = "⚠️ [\(category)] \(message)"
        logger.warning("\(formattedMessage)")
        #if DEBUG
            print(formattedMessage)
        #endif
    }

    /// Errors that need attention
    public func error(_ message: String, error: Error? = nil) {
        let formattedMessage: String
        if let error = error {
            formattedMessage = "❌ [\(category)] \(message): \(error.localizedDescription)"
        } else {
            formattedMessage = "❌ [\(category)] \(message)"
        }
        logger.error("\(formattedMessage)")
        #if DEBUG
            print(formattedMessage)
        #endif
    }

    /// Critical errors that may cause app instability
    public func critical(_ message: String, error: Error? = nil) {
        let formattedMessage: String
        if let error = error {
            formattedMessage = "🚨 [\(category)] \(message): \(error.localizedDescription)"
        } else {
            formattedMessage = "🚨 [\(category)] \(message)"
        }
        logger.critical("\(formattedMessage)")
        #if DEBUG
            print(formattedMessage)
        #endif
    }

    // MARK: - Performance Logging

    /// Log performance metrics
    public func performance(_ message: String, timeInterval: TimeInterval) {
        logger.info("⏱️ [\(category)] \(message): \(String(format: "%.3f", timeInterval))s")
    }

    // MARK: - Network Logging

    /// Log network requests (with privacy protection)
    public func network(_ message: String, url: String? = nil, statusCode: Int? = nil) {
        var logMessage = "🌐 [\(category)] \(message)"
        if let url = url {
            // Redact sensitive query parameters
            let sanitizedURL = sanitizeURL(url)
            logMessage += " - URL: \(sanitizedURL)"
        }
        if let statusCode = statusCode {
            logMessage += " - Status: \(statusCode)"
        }
        logger.info("\(logMessage)")
    }

    // MARK: - Data Logging

    /// Log data operations with privacy
    public func data(_ message: String, count: Int? = nil) {
        var logMessage = "💾 [\(category)] \(message)"
        if let count = count {
            logMessage += " - Count: \(count)"
        }
        logger.debug("\(logMessage)")
    }

    // MARK: - Private Helpers

    private func sanitizeURL(_ urlString: String) -> String {
        // Remove sensitive query parameters
        guard let url = URL(string: urlString),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return urlString
        }

        // Redact sensitive query items
        let sensitiveParams = ["token", "password", "secret", "key", "auth"]
        components.queryItems = components.queryItems?.map { item in
            if sensitiveParams.contains(where: { item.name.lowercased().contains($0) }) {
                return URLQueryItem(name: item.name, value: "[REDACTED]")
            }
            return item
        }

        return components.string ?? urlString
    }
}

// MARK: - Convenience Loggers

public extension Logger {
    static let auth = Logger(category: "Auth")
    static let network = Logger(category: "Network")
    static let ui = Logger(category: "UI")
    static let data = Logger(category: "Data")
    static let household = Logger(category: "Household")
    static let jeeves = Logger(category: "Jeeves")
    static let notification = Logger(category: "Notification")
    static let graphql = Logger(category: "GraphQL")
    static let shopping = Logger(category: "Shopping")
    static let app = Logger(category: "App")
    static let di = Logger(category: "DI")
    static let permissions = Logger(category: "Permissions")
    static let cache = Logger(category: "Cache")
}
