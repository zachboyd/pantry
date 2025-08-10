import Foundation

/// Index for efficient rule storage and retrieval
/// Provides O(1) lookup for basic action/subject type combinations
public actor RuleIndex {
    /// Rules indexed by action and subject type for O(1) lookup
    private var index: [IndexKey: [Rule]] = [:]

    /// All rules in insertion order
    private var allRules: [Rule] = []

    /// Rules that apply to all actions or subjects
    private var wildcardRules: [Rule] = []

    /// Add a rule to the index
    func add(_ rule: Rule) {
        allRules.append(rule)

        // Check if this is a wildcard rule
        let isWildcardAction = rule.action == .manage || rule.action == .all
        let isWildcardSubject = rule.subject == .all || rule.subject == .any

        if isWildcardAction || isWildcardSubject {
            wildcardRules.append(rule)
        }

        // Index by specific action/subject combinations
        let key = IndexKey(action: rule.action, subject: rule.subject)
        if index[key] == nil {
            index[key] = []
        }
        index[key]?.append(rule)

        // Sort rules by priority after adding
        sortRules()
    }

    /// Add multiple rules at once
    func addRules(_ rules: [Rule]) {
        for rule in rules {
            allRules.append(rule)

            let isWildcardAction = rule.action == .manage || rule.action == .all
            let isWildcardSubject = rule.subject == .all || rule.subject == .any

            if isWildcardAction || isWildcardSubject {
                wildcardRules.append(rule)
            }

            let key = IndexKey(action: rule.action, subject: rule.subject)
            if index[key] == nil {
                index[key] = []
            }
            index[key]?.append(rule)
        }

        sortRules()
    }

    /// Get relevant rules for an action and subject type
    func relevantRules(for action: Action, subjectType: SubjectType) -> [Rule] {
        var rules: [Rule] = []

        // 1. Get exact matches
        let exactKey = IndexKey(action: action, subject: subjectType)
        if let exactRules = index[exactKey] {
            rules.append(contentsOf: exactRules)
        }

        // 2. Get wildcard rules that might apply
        rules.append(contentsOf: wildcardRules.filter { rule in
            rule.matches(action: action, subjectType: subjectType)
        })

        // 3. Sort by precedence
        rules.sort(by: <)

        return rules
    }

    /// Get all rules
    func getAllRules() -> [Rule] {
        allRules
    }

    /// Clear all rules
    func clear() {
        index.removeAll()
        allRules.removeAll()
        wildcardRules.removeAll()
    }

    /// Update the index (rebuild from current rules)
    func rebuild() {
        let rules = allRules
        clear()
        addRules(rules)
    }

    // MARK: - Private

    private func sortRules() {
        // Sort all rule arrays by precedence
        for key in index.keys {
            index[key]?.sort(by: <)
        }
        wildcardRules.sort(by: <)
    }

    // Index key for combining action and subject
    private struct IndexKey: Hashable {
        let action: Action
        let subject: SubjectType
    }
}

// Public functions for rule matching
public extension RuleIndex {
    /// Find the first applicable rule for the given action and subject
    func findRule(
        for action: Action,
        subjectType: SubjectType,
        evaluateConditions: ((Rule) -> Bool)? = nil
    ) async -> Rule? {
        let rules = relevantRules(for: action, subjectType: subjectType)

        for rule in rules {
            // If there's no condition evaluator, return rules without conditions
            guard let evaluateConditions = evaluateConditions else {
                if !rule.hasConditions {
                    return rule
                }
                continue
            }

            // Evaluate conditions if provided
            if !rule.hasConditions || evaluateConditions(rule) {
                return rule
            }
        }

        return nil
    }

    /// Check if any rule allows the action
    func isAllowed(
        action: Action,
        subjectType: SubjectType,
        evaluateConditions: ((Rule) -> Bool)? = nil
    ) async -> Bool {
        if let rule = await findRule(
            for: action,
            subjectType: subjectType,
            evaluateConditions: evaluateConditions
        ) {
            // If we found a rule, check if it's inverted
            return !rule.inverted
        }

        // No rule found means not allowed
        return false
    }
}
