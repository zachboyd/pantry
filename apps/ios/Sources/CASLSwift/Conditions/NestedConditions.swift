import Foundation

/// Extensions for handling nested conditions and complex queries
extension Conditions {
    
    /// Create conditions with logical operators
    public static func and(_ conditions: [Conditions]) -> Conditions {
        let data = conditions.map { $0.data }
        return Conditions([ConditionOperator.and.rawValue: data])
    }
    
    public static func or(_ conditions: [Conditions]) -> Conditions {
        let data = conditions.map { $0.data }
        return Conditions([ConditionOperator.or.rawValue: data])
    }
    
    public static func not(_ conditions: Conditions) -> Conditions {
        return Conditions([ConditionOperator.not.rawValue: conditions.data])
    }
    
    /// Create field conditions with operators
    public static func field(_ name: String, eq value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.eq.rawValue: value]])
    }
    
    public static func field(_ name: String, ne value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.ne.rawValue: value]])
    }
    
    public static func field(_ name: String, gt value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.gt.rawValue: value]])
    }
    
    public static func field(_ name: String, gte value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.gte.rawValue: value]])
    }
    
    public static func field(_ name: String, lt value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.lt.rawValue: value]])
    }
    
    public static func field(_ name: String, lte value: Any) -> Conditions {
        return Conditions([name: [ConditionOperator.lte.rawValue: value]])
    }
    
    public static func field(_ name: String, in values: [Any]) -> Conditions {
        return Conditions([name: [ConditionOperator.in.rawValue: values]])
    }
    
    public static func field(_ name: String, nin values: [Any]) -> Conditions {
        return Conditions([name: [ConditionOperator.nin.rawValue: values]])
    }
    
    public static func field(_ name: String, exists: Bool = true) -> Conditions {
        return Conditions([name: [ConditionOperator.exists.rawValue: exists]])
    }
    
    public static func field(_ name: String, regex pattern: String) -> Conditions {
        return Conditions([name: [ConditionOperator.regex.rawValue: pattern]])
    }
}

/// Builder for creating complex nested conditions
@resultBuilder
public struct ConditionsBuilder {
    public static func buildBlock(_ conditions: Conditions...) -> Conditions {
        // If only one condition, return it directly
        if conditions.count == 1 {
            return conditions[0]
        }
        // Otherwise, combine with AND
        return .and(conditions)
    }
    
    public static func buildOptional(_ conditions: Conditions?) -> Conditions {
        conditions ?? .empty
    }
    
    public static func buildEither(first conditions: Conditions) -> Conditions {
        conditions
    }
    
    public static func buildEither(second conditions: Conditions) -> Conditions {
        conditions
    }
    
    public static func buildArray(_ conditions: [Conditions]) -> Conditions {
        if conditions.isEmpty {
            return .empty
        } else if conditions.count == 1 {
            return conditions[0]
        } else {
            return .and(conditions)
        }
    }
}

/// Convenience functions for building conditions
public func conditions(@ConditionsBuilder builder: () -> Conditions) -> Conditions {
    builder()
}

/// Example usage:
/// let myConditions = conditions {
///     Conditions.field("age", gte: 18)
///     Conditions.field("role", in: ["admin", "moderator"])
///     Conditions.or([
///         Conditions.field("status", eq: "active"),
///         Conditions.field("verified", eq: true)
///     ])
/// }