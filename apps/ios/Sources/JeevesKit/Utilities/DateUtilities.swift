//
//  DateUtilities.swift
//  JeevesKit
//
//  Centralized date conversion utilities for GraphQL DateTime handling
//

import Foundation

/// Centralized date utilities for converting between GraphQL DateTime strings and Foundation Date objects
public enum DateUtilities {
    /// Thread-safe date formatter wrapper
    private static let dateFormatterQueue = DispatchQueue(label: "com.pantrykit.dateformatters")

    /// Shared ISO8601 date formatter configured for GraphQL DateTime format
    /// Format: "2019-12-03T09:54:33Z" (UTC timezone)
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Alternative formatter for dates without fractional seconds
    private nonisolated(unsafe) static let iso8601FormatterNoFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Converts a GraphQL DateTime string to a Foundation Date
    /// - Parameter dateTimeString: The GraphQL DateTime string (e.g., "2019-12-03T09:54:33.123Z")
    /// - Returns: A Date object, or nil if the string cannot be parsed
    public static func dateFromGraphQL(_ dateTimeString: String) -> Date? {
        dateFormatterQueue.sync {
            // Try with fractional seconds first
            if let date = iso8601Formatter.date(from: dateTimeString) {
                return date
            }
            // Fallback to without fractional seconds
            return iso8601FormatterNoFractionalSeconds.date(from: dateTimeString)
        }
    }

    /// Converts a GraphQL DateTime string to a Foundation Date with a fallback to current date
    /// - Parameter dateTimeString: The GraphQL DateTime string
    /// - Returns: A Date object, or current date if the string cannot be parsed
    public static func dateFromGraphQLOrNow(_ dateTimeString: String) -> Date {
        dateFromGraphQL(dateTimeString) ?? Date()
    }

    /// Converts a Foundation Date to a GraphQL DateTime string
    /// - Parameter date: The Date object to convert
    /// - Returns: A GraphQL DateTime string in ISO8601 format with fractional seconds
    public static func graphQLStringFromDate(_ date: Date) -> String {
        dateFormatterQueue.sync {
            iso8601Formatter.string(from: date)
        }
    }

    /// Converts an optional GraphQL DateTime string to an optional Date
    /// - Parameter dateTimeString: The optional GraphQL DateTime string
    /// - Returns: An optional Date object
    public static func dateFromGraphQL(_ dateTimeString: String?) -> Date? {
        guard let dateTimeString = dateTimeString else { return nil }
        return dateFromGraphQL(dateTimeString)
    }

    /// Converts an optional Date to an optional GraphQL DateTime string
    /// - Parameter date: The optional Date object
    /// - Returns: An optional GraphQL DateTime string
    public static func graphQLStringFromDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        return graphQLStringFromDate(date)
    }
}
