import Foundation

/// Protocol for validating field-level permissions
public protocol FieldValidator: Sendable {
    /// Validate if a field can be accessed based on the permitted fields
    func canAccessField(_ field: String, permittedFields: Set<String>?) -> Bool

    /// Filter an object to only include permitted fields
    func filterFields<T>(of object: T, permittedFields: Set<String>?) -> [String: Any]
}

/// Default implementation of field validation
public struct DefaultFieldValidator: FieldValidator {
    public init() {}

    public func canAccessField(_ field: String, permittedFields: Set<String>?) -> Bool {
        // If no field restrictions, all fields are permitted
        guard let permittedFields = permittedFields else {
            return true
        }

        // Check if field is in permitted set
        return permittedFields.contains(field)
    }

    public func filterFields<T>(of object: T, permittedFields: Set<String>?) -> [String: Any] {
        // If no field restrictions, return all fields
        guard let permittedFields = permittedFields else {
            return getAllFields(of: object)
        }

        // Filter to only permitted fields
        let allFields = getAllFields(of: object)
        return allFields.filter { permittedFields.contains($0.key) }
    }

    private func getAllFields<T>(of object: T) -> [String: Any] {
        var fields: [String: Any] = [:]

        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            if let label = child.label {
                fields[label] = child.value
            }
        }

        return fields
    }
}

/// Field validator with support for nested field paths
public struct NestedFieldValidator: FieldValidator {
    public init() {}

    public func canAccessField(_ field: String, permittedFields: Set<String>?) -> Bool {
        // If no field restrictions, all fields are permitted
        guard let permittedFields = permittedFields else {
            return true
        }

        // Direct match
        if permittedFields.contains(field) {
            return true
        }

        // Check for wildcard patterns (e.g., "address.*" permits "address.city")
        let fieldParts = field.split(separator: ".").map(String.init)
        for i in 1 ... fieldParts.count {
            let prefix = fieldParts.prefix(i).joined(separator: ".")
            if permittedFields.contains("\(prefix).*") {
                return true
            }
        }

        return false
    }

    public func filterFields<T>(of object: T, permittedFields: Set<String>?) -> [String: Any] {
        // If no field restrictions, return all fields
        guard let permittedFields = permittedFields else {
            return getAllFieldsRecursive(of: object)
        }

        // Filter to only permitted fields (including nested)
        return filterFieldsRecursive(of: object, permittedFields: permittedFields, currentPath: "")
    }

    private func getAllFieldsRecursive<T>(of object: T, currentPath: String = "") -> [String: Any] {
        var fields: [String: Any] = [:]

        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            guard let label = child.label else { continue }

            let fieldPath = currentPath.isEmpty ? label : "\(currentPath).\(label)"

            // Check if this is a nested object
            if isNestedObject(child.value) {
                // Recursively get nested fields
                let nestedFields = getAllFieldsRecursive(of: child.value, currentPath: fieldPath)
                fields.merge(nestedFields) { _, new in new }
            } else {
                fields[fieldPath] = child.value
            }
        }

        return fields
    }

    private func filterFieldsRecursive<T>(of object: T, permittedFields: Set<String>, currentPath: String) -> [String: Any] {
        var fields: [String: Any] = [:]

        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            guard let label = child.label else { continue }

            let fieldPath = currentPath.isEmpty ? label : "\(currentPath).\(label)"

            // Check if this field is permitted
            if canAccessField(fieldPath, permittedFields: permittedFields) {
                if isNestedObject(child.value) {
                    // Include all nested fields if parent is permitted
                    let nestedFields = getAllFieldsRecursive(of: child.value, currentPath: fieldPath)
                    fields.merge(nestedFields) { _, new in new }
                } else {
                    fields[fieldPath] = child.value
                }
            } else if isNestedObject(child.value) {
                // Check if any nested fields are permitted
                let nestedFields = filterFieldsRecursive(of: child.value, permittedFields: permittedFields, currentPath: fieldPath)
                fields.merge(nestedFields) { _, new in new }
            }
        }

        return fields
    }

    private func isNestedObject(_ value: Any) -> Bool {
        // Check if this is a custom object (not a primitive or collection)
        let mirror = Mirror(reflecting: value)

        // Skip primitives and standard collections
        if value is String || value is Int || value is Double || value is Bool ||
            value is Date || value is UUID || value is URL ||
            value is [Any] || value is [String: Any] ||
            value is Set<AnyHashable>
        {
            return false
        }

        // Check if it has properties
        return mirror.children.count > 0
    }
}

/// Extension to make field validation easier on Ability
public extension Ability {
    /// Check if a specific field can be accessed for an action on a subject
    func canAccessField(_ field: String, for action: A, on subject: any Subject) async -> Bool {
        let permittedFields = await permittedFieldsBy(action, subject)
        let validator = DefaultFieldValidator()
        return validator.canAccessField(field, permittedFields: permittedFields)
    }

    /// Filter an object to only include fields permitted for an action
    func filterPermittedFields<T>(_ object: T, for action: A, on subject: any Subject) async -> [String: Any] {
        let permittedFields = await permittedFieldsBy(action, subject)
        let validator = NestedFieldValidator()
        return validator.filterFields(of: object, permittedFields: permittedFields)
    }
}

/// Utility struct for extracting fields from conditions
public struct FieldExtractor {
    public init() {}

    /// Extract all field names referenced in conditions
    public func extractFields(from conditions: Conditions) -> Set<String> {
        var fields = Set<String>()
        extractFieldsRecursive(from: conditions.data, prefix: "", into: &fields)
        return fields
    }

    private func extractFieldsRecursive(from dict: [String: Any], prefix: String, into fields: inout Set<String>) {
        for (key, value) in dict {
            // Skip operator keys
            if key.starts(with: "$") {
                // Handle logical operators that contain nested conditions
                if key == "$and" || key == "$or" {
                    if let array = value as? [[String: Any]] {
                        for item in array {
                            extractFieldsRecursive(from: item, prefix: prefix, into: &fields)
                        }
                    }
                } else if key == "$not" {
                    if let nestedDict = value as? [String: Any] {
                        extractFieldsRecursive(from: nestedDict, prefix: prefix, into: &fields)
                    }
                }
                // For other operators, we don't extract the operator itself as a field
            } else {
                // This is a field name
                let fieldPath = prefix.isEmpty ? key : "\(prefix).\(key)"
                fields.insert(fieldPath)

                // If the value is a nested dictionary that doesn't contain operators,
                // it might be a nested object condition
                if let nestedDict = value as? [String: Any] {
                    let hasOperators = nestedDict.keys.contains { $0.starts(with: "$") }
                    if !hasOperators {
                        // This is a nested object condition, extract nested fields
                        extractFieldsRecursive(from: nestedDict, prefix: fieldPath, into: &fields)
                        // Remove the parent field since we have more specific nested fields
                        fields.remove(fieldPath)
                    }
                }
            }
        }
    }
}
