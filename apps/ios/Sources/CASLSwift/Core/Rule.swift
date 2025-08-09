import Foundation

/// Represents a permission rule in the system
public struct Rule: Sendable {
    /// The action this rule applies to
    public let action: Action
    
    /// The subject type this rule applies to
    public let subject: SubjectType
    
    /// Optional conditions that must be met for the rule to apply
    public let conditions: Conditions?
    
    /// Whether this is an inverted rule (cannot instead of can)
    public let inverted: Bool
    
    /// Optional fields this rule applies to
    public let fields: [String]?
    
    /// Optional reason for this rule (useful for debugging)
    public let reason: String?
    
    /// Priority for rule evaluation (higher priority rules are evaluated first)
    public let priority: Int
    
    public init(
        action: Action,
        subject: SubjectType,
        conditions: Conditions? = nil,
        inverted: Bool = false,
        fields: [String]? = nil,
        reason: String? = nil,
        priority: Int = 0
    ) {
        self.action = action
        self.subject = subject
        self.conditions = conditions
        self.inverted = inverted
        self.fields = fields
        self.reason = reason
        self.priority = priority
    }
}

// Rule matching
extension Rule {
    /// Check if this rule matches the given action and subject type
    /// Note: Inverted rules (cannot rules) always return false from matches()
    /// as they represent negative permissions
    public func matches(action: Action, subjectType: SubjectType) -> Bool {
        // Inverted rules never "match" in the positive sense
        if inverted {
            return false
        }
        return matchesAction(action) && matchesSubjectType(subjectType)
    }
    
    /// Check if this rule's action matches the given action
    public func matchesAction(_ action: Action) -> Bool {
        // "manage" or "all" actions match everything
        if self.action == .manage || self.action == .all {
            return true
        }
        return self.action == action
    }
    
    /// Check if this rule's subject type matches the given subject type
    public func matchesSubjectType(_ subjectType: SubjectType) -> Bool {
        // "all" or "any" subject types match everything
        if self.subject == .all || self.subject == .any {
            return true
        }
        return self.subject == subjectType
    }
    
    /// Check if this rule has conditions that need to be evaluated
    public var hasConditions: Bool {
        conditions != nil && !conditions!.isEmpty
    }
    
    /// Check if this rule has field restrictions
    public var hasFieldRestrictions: Bool {
        fields != nil && !fields!.isEmpty
    }
}

// Rule precedence
extension Rule {
    /// Compare rules for sorting by priority and specificity
    public static func < (lhs: Rule, rhs: Rule) -> Bool {
        // First, sort by priority (higher priority first)
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        
        // Then, inverted rules (cannot) take precedence over non-inverted (can)
        if lhs.inverted != rhs.inverted {
            return lhs.inverted
        }
        
        // Rules with conditions are more specific than those without
        if lhs.hasConditions != rhs.hasConditions {
            return lhs.hasConditions
        }
        
        // Rules with specific fields are more specific than those without
        let lhsHasFields = lhs.fields != nil && !lhs.fields!.isEmpty
        let rhsHasFields = rhs.fields != nil && !rhs.fields!.isEmpty
        if lhsHasFields != rhsHasFields {
            return lhsHasFields
        }
        
        // More specific subject types come first
        let lhsIsGenericSubject = lhs.subject == .all || lhs.subject == .any
        let rhsIsGenericSubject = rhs.subject == .all || rhs.subject == .any
        if lhsIsGenericSubject != rhsIsGenericSubject {
            return !lhsIsGenericSubject
        }
        
        // More specific actions come first
        let lhsIsGenericAction = lhs.action == .manage || lhs.action == .all
        let rhsIsGenericAction = rhs.action == .manage || rhs.action == .all
        if lhsIsGenericAction != rhsIsGenericAction {
            return !lhsIsGenericAction
        }
        
        // Otherwise, they're equal in precedence
        return false
    }
}