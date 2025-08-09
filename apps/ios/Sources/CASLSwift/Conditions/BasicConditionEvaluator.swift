import Foundation

/// Basic implementation of condition evaluation
public struct BasicConditionEvaluator: ConditionEvaluator {
    private let matcher: ConditionsMatcher
    
    public init(matcher: ConditionsMatcher = MongoDBConditionsMatcher()) {
        self.matcher = matcher
    }
    
    public func evaluate(_ conditions: Conditions, against subject: any Subject) -> Bool {
        matcher.matches(conditions, against: subject)
    }
    
    /// Convenience method for matching dictionary objects against conditions
    public func matches(object: [String: Any], conditions: Conditions) -> Bool {
        // Create a dictionary subject wrapper that conforms to Subject protocol
        let subject = DictionarySubject(properties: object)
        return evaluate(conditions, against: subject)
    }
}