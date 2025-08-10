import Foundation

/// Protocol for matching conditions against subjects
public protocol ConditionsMatcher: Sendable {
    /// Match conditions against a subject
    func matches(_ conditions: Conditions, against subject: any Subject) -> Bool

    /// Match a specific field condition
    func matchesField(_ field: String, condition: Any, in subject: any Subject) -> Bool
}

/// Default implementation of ConditionsMatcher using MongoDB-style operators
public struct MongoDBConditionsMatcher: ConditionsMatcher {
    public init() {}

    public func matches(_ conditions: Conditions, against subject: any Subject) -> Bool {
        guard !conditions.isEmpty else { return true }

        let data = conditions.data

        // Check each condition
        for (key, value) in data {
            // Handle logical operators
            if let op = ConditionOperator(rawValue: key) {
                switch op {
                case .and:
                    if let array = value as? [[String: Any]] {
                        let subConditions = array.map { Conditions($0) }
                        if !subConditions.allSatisfy({ matches($0, against: subject) }) {
                            return false
                        }
                    }
                case .or:
                    if let array = value as? [[String: Any]] {
                        let subConditions = array.map { Conditions($0) }
                        if !subConditions.contains(where: { matches($0, against: subject) }) {
                            return false
                        }
                    }
                case .not:
                    if let dict = value as? [String: Any] {
                        let subCondition = Conditions(dict)
                        if matches(subCondition, against: subject) {
                            return false
                        }
                    }
                default:
                    // Not a top-level logical operator
                    continue
                }
            } else {
                // Regular field condition
                if !matchesField(key, condition: value, in: subject) {
                    return false
                }
            }
        }

        return true
    }

    public func matchesField(_ field: String, condition: Any, in subject: any Subject) -> Bool {
        // Get the field value from the subject
        let fieldValue = getFieldValue(field, from: subject)

        // If condition is a dictionary, it might contain operators or nested field conditions
        if let conditionDict = condition as? [String: Any] {
            // Check if all keys are operators
            let hasOnlyOperators = conditionDict.keys.allSatisfy { ConditionOperator(rawValue: $0) != nil }

            if hasOnlyOperators {
                // All keys are operators, evaluate them
                for (opString, expectedValue) in conditionDict {
                    guard let op = ConditionOperator(rawValue: opString),
                          matchesOperator(op, fieldValue: fieldValue, expectedValue: expectedValue)
                    else {
                        return false
                    }
                }
                return true
            } else {
                // Keys are nested fields, evaluate each nested field condition
                for (nestedField, nestedCondition) in conditionDict {
                    let fullFieldPath = "\(field).\(nestedField)"
                    if !matchesField(fullFieldPath, condition: nestedCondition, in: subject) {
                        return false
                    }
                }
                return true
            }
        } else {
            // Direct equality check
            return isEqual(fieldValue, condition)
        }
    }

    private func matchesOperator(_ op: ConditionOperator, fieldValue: Any?, expectedValue: Any) -> Bool {
        switch op {
        case .eq:
            return isEqual(fieldValue, expectedValue)

        case .ne:
            return !isEqual(fieldValue, expectedValue)

        case .gt:
            return compare(fieldValue, expectedValue) > 0

        case .gte:
            return compare(fieldValue, expectedValue) >= 0

        case .lt:
            return compare(fieldValue, expectedValue) < 0

        case .lte:
            return compare(fieldValue, expectedValue) <= 0

        case .in:
            guard let array = expectedValue as? [Any] else { return false }
            return array.contains { isEqual(fieldValue, $0) }

        case .nin:
            guard let array = expectedValue as? [Any] else { return false }
            return !array.contains { isEqual(fieldValue, $0) }

        case .exists:
            let shouldExist = expectedValue as? Bool ?? true
            return (fieldValue != nil) == shouldExist

        case .regex:
            guard let pattern = expectedValue as? String,
                  let fieldString = fieldValue as? String else { return false }
            return fieldString.range(of: pattern, options: .regularExpression) != nil

        case .and, .or, .not:
            // These are handled at the top level
            return true
        }
    }

    private func getFieldValue(_ field: String, from subject: any Subject) -> Any? {
        // Check if subject is a DictionarySubject
        if let dictSubject = subject as? DictionarySubject {
            // Handle nested fields (e.g., "address.city")
            let fieldParts = field.split(separator: ".").map(String.init)
            var currentValue: Any? = dictSubject[fieldParts[0]]

            for part in fieldParts.dropFirst() {
                guard let value = currentValue else { return nil }

                if let dict = value as? [String: Any] {
                    currentValue = dict[part]
                } else {
                    let mirror = Mirror(reflecting: value)
                    currentValue = mirror.children.first { $0.label == part }?.value
                }
            }

            return currentValue
        }

        // Handle nested fields (e.g., "address.city")
        let fieldParts = field.split(separator: ".").map(String.init)
        var currentValue: Any? = subject

        for part in fieldParts {
            guard let value = currentValue else { return nil }

            let mirror = Mirror(reflecting: value)
            currentValue = mirror.children.first { $0.label == part }?.value
        }

        return currentValue
    }

    private func isEqual(_ lhs: Any?, _ rhs: Any) -> Bool {
        // Handle nil and NSNull cases
        // Missing field (nil) should NOT match NSNull condition
        if lhs == nil && rhs is NSNull { return false }
        if lhs == nil { return false }
        if lhs is NSNull && rhs is NSNull { return true }
        guard let lhs = lhs else { return false }

        // Convert to comparable types
        switch (lhs, rhs) {
        case let (l as String, r as String):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as NSNumber, r as NSNumber):
            return l == r
        default:
            // Try string comparison as fallback
            return "\(lhs)" == "\(rhs)"
        }
    }

    private func compare(_ lhs: Any?, _ rhs: Any) -> Int {
        guard let lhs = lhs else { return -1 }

        switch (lhs, rhs) {
        case let (l as Int, r as Int):
            return l < r ? -1 : (l > r ? 1 : 0)
        case let (l as Double, r as Double):
            return l < r ? -1 : (l > r ? 1 : 0)
        case let (l as String, r as String):
            return l < r ? -1 : (l > r ? 1 : 0)
        case let (l as NSNumber, r as NSNumber):
            return l.compare(r).rawValue
        default:
            return 0
        }
    }
}

/// Custom conditions matcher that can be extended
public struct CustomConditionsMatcher: ConditionsMatcher {
    private let customMatchers: [String: @Sendable (Any?, Any) -> Bool]
    private let fallback: ConditionsMatcher

    public init(
        customMatchers: [String: @Sendable (Any?, Any) -> Bool] = [:],
        fallback: ConditionsMatcher = MongoDBConditionsMatcher()
    ) {
        self.customMatchers = customMatchers
        self.fallback = fallback
    }

    public func matches(_ conditions: Conditions, against subject: any Subject) -> Bool {
        // Use fallback for standard matching
        fallback.matches(conditions, against: subject)
    }

    public func matchesField(_ field: String, condition: Any, in subject: any Subject) -> Bool {
        // Check if we have a custom matcher for this field
        if let customMatcher = customMatchers[field] {
            let fieldValue = getFieldValue(field, from: subject)
            return customMatcher(fieldValue, condition)
        }

        // Otherwise use fallback
        return fallback.matchesField(field, condition: condition, in: subject)
    }

    private func getFieldValue(_ field: String, from subject: any Subject) -> Any? {
        let mirror = Mirror(reflecting: subject)
        return mirror.children.first { $0.label == field }?.value
    }
}
