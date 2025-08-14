// @generated
// This file was automatically generated and can be edited to
// implement advanced custom scalar functionality.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

import ApolloAPI
import Foundation

/// Custom JSON scalar implementation that handles conversion between JSON data and String
public struct JSONValue: JSONDecodable, JSONEncodable, OutputTypeConvertible, AnyScalarType, ScalarType, Hashable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }

    public init(_jsonValue value: ApolloAPI.JSONValue) throws {
        // Handle different types of JSON values from server
        if let stringValue = value as? String {
            // Server sends JSON as a string - could be double-encoded
            if stringValue.isEmpty {
                self.value = "[]" // Default to empty array
            } else if let data = stringValue.data(using: .utf8) {
                // Try to parse as JSON first
                if let parsed = try? JSONSerialization.jsonObject(with: data) {
                    // It's valid JSON
                    // Check if it's double-encoded (a string containing JSON)
                    if let innerString = parsed as? String,
                       let innerData = innerString.data(using: .utf8),
                       let _ = try? JSONSerialization.jsonObject(with: innerData)
                    {
                        // Double-encoded - use the inner JSON string
                        self.value = innerString
                    } else {
                        // Single-encoded - use as is
                        self.value = stringValue
                    }
                } else {
                    // Not valid JSON, treat as plain string
                    self.value = "\"\(stringValue)\""
                }
            } else {
                self.value = "\"\(stringValue)\""
            }
        } else if value is NSNull {
            // Handle null value
            self.value = "null"
        } else {
            // Convert complex JSON (array/dictionary) to string
            let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes])
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw JSONDecodingError.couldNotConvert(value: value, to: String.self)
            }
            self.value = jsonString
        }
    }

    public var _jsonValue: ApolloAPI.JSONValue {
        // When sending to server, keep as string
        value
    }

    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        lhs.value == rhs.value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }

    // OutputTypeConvertible conformance
    public static var _asOutputType: ApolloAPI.Selection.Field.OutputType {
        .scalar(JSONValue.self)
    }
}

public extension JeevesGraphQL {
    /// The `JSON` scalar type represents JSON values as specified by [ECMA-404](http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf).
    /// This custom implementation handles conversion between server JSON arrays/objects and String storage.
    typealias JSON = JSONValue
}
