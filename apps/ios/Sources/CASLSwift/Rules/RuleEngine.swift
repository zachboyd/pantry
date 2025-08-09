import Foundation

/// Engine for evaluating permission rules
public actor RuleEngine {
    private let ruleIndex: RuleIndex
    private var conditionEvaluator: ConditionEvaluator?
    
    public init() {
        self.ruleIndex = RuleIndex()
    }
    
    /// Set the condition evaluator
    public func setConditionEvaluator(_ evaluator: ConditionEvaluator) {
        self.conditionEvaluator = evaluator
    }
    
    /// Add a rule to the engine
    public func addRule(_ rule: Rule) async {
        await ruleIndex.add(rule)
    }
    
    /// Add multiple rules to the engine
    public func addRules(_ rules: [Rule]) async {
        await ruleIndex.addRules(rules)
    }
    
    /// Check if an action is allowed on a subject
    public func can(
        _ action: Action,
        _ subject: any Subject
    ) async -> Bool {
        let subjectType = subject.subjectType
        
        // Capture evaluator locally to avoid actor isolation issues
        let evaluator = self.conditionEvaluator
        
        // Find applicable rules
        let rule = await ruleIndex.findRule(
            for: action,
            subjectType: subjectType,
            evaluateConditions: { rule in
                guard rule.hasConditions,
                      let evaluator = evaluator else {
                    return true
                }
                
                // For type-based checks (using TypedSubject), skip condition evaluation
                // as we're asking about general permissions on a subject type, not specific instances
                if String(describing: type(of: subject)) == "TypedSubject" {
                    return true
                }
                
                return evaluator.evaluate(rule.conditions!, against: subject)
            }
        )
        
        // If we found a rule, return whether it allows (not inverted) the action
        if let rule = rule {
            return !rule.inverted
        }
        
        // No rule found means not allowed
        return false
    }
    
    /// Check if an action is forbidden on a subject
    public func cannot(
        _ action: Action,
        _ subject: any Subject
    ) async -> Bool {
        !(await can(action, subject))
    }
    
    /// Get all rules that apply to a subject
    public func rulesFor(
        _ subject: any Subject
    ) async -> [Rule] {
        await ruleIndex.getAllRules().filter { rule in
            rule.matchesSubjectType(subject.subjectType)
        }
    }
    
    /// Get permitted fields for an action on a subject
    public func permittedFieldsBy(
        _ action: Action,
        _ subject: any Subject
    ) async -> Set<String>? {
        let subjectType = subject.subjectType
        let rules = await ruleIndex.relevantRules(for: action, subjectType: subjectType)
        
        // Capture evaluator locally
        let evaluator = self.conditionEvaluator
        
        var permittedFields: Set<String>?
        var hasFieldRestrictions = false
        
        for rule in rules {
            // Skip rules with conditions unless they match
            if rule.hasConditions {
                if let evaluator = evaluator,
                   !evaluator.evaluate(rule.conditions!, against: subject) {
                    continue
                }
            }
            
            // If rule has field restrictions
            if let fields = rule.fields {
                hasFieldRestrictions = true
                
                if rule.inverted {
                    // Remove fields for inverted rules
                    if permittedFields == nil {
                        // If this is the first rule with fields, we can't remove from nothing
                        continue
                    }
                    permittedFields?.subtract(fields)
                } else {
                    // Add fields for normal rules
                    if permittedFields == nil {
                        permittedFields = Set(fields)
                    } else {
                        permittedFields?.formUnion(fields)
                    }
                }
            } else if !rule.inverted && !hasFieldRestrictions {
                // If a rule allows all fields and we haven't seen field restrictions yet,
                // return nil to indicate all fields are allowed
                return nil
            }
        }
        
        return permittedFields
    }
    
    /// Clear all rules
    public func clear() async {
        await ruleIndex.clear()
    }
    
    /// Get all rules currently in the engine
    public func getRules() async -> [Rule] {
        await ruleIndex.getAllRules()
    }
}

/// Protocol for evaluating conditions
public protocol ConditionEvaluator: Sendable {
    /// Evaluate conditions against a subject
    func evaluate(_ conditions: Conditions, against subject: any Subject) -> Bool
}