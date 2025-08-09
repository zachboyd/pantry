import XCTest
@testable import CASLSwift

final class ConditionEvaluationTests: XCTestCase {
    
    // MARK: - Basic Condition Matching
    
    func testEqualityCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions(["userId": "123"])
        
        let matchingObject: [String: Any] = ["userId": "123", "name": "Test"]
        let nonMatchingObject: [String: Any] = ["userId": "456", "name": "Test"]
        
        XCTAssertTrue(evaluator.matches(object: matchingObject, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: nonMatchingObject, conditions: conditions))
    }
    
    func testMultipleEqualityConditions() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "userId": "123",
            "householdId": "abc"
        ])
        
        let fullMatch: [String: Any] = ["userId": "123", "householdId": "abc", "other": "data"]
        let partialMatch: [String: Any] = ["userId": "123", "householdId": "xyz"]
        let noMatch: [String: Any] = ["userId": "456", "householdId": "xyz"]
        
        XCTAssertTrue(evaluator.matches(object: fullMatch, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: partialMatch, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: noMatch, conditions: conditions))
    }
    
    // MARK: - Comparison Operators
    
    func testGreaterThanCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "age": ["$gt": 18]
        ])
        
        let adult: [String: Any] = ["age": 25]
        let teen: [String: Any] = ["age": 16]
        let exactly18: [String: Any] = ["age": 18]
        
        XCTAssertTrue(evaluator.matches(object: adult, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: teen, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: exactly18, conditions: conditions))
    }
    
    func testLessThanCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "price": ["$lt": 100]
        ])
        
        let cheap: [String: Any] = ["price": 50]
        let expensive: [String: Any] = ["price": 150]
        let exactly100: [String: Any] = ["price": 100]
        
        XCTAssertTrue(evaluator.matches(object: cheap, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: expensive, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: exactly100, conditions: conditions))
    }
    
    func testGreaterThanOrEqualCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "score": ["$gte": 60]
        ])
        
        let pass: [String: Any] = ["score": 75]
        let barelyPass: [String: Any] = ["score": 60]
        let fail: [String: Any] = ["score": 45]
        
        XCTAssertTrue(evaluator.matches(object: pass, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: barelyPass, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: fail, conditions: conditions))
    }
    
    func testLessThanOrEqualCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "quantity": ["$lte": 10]
        ])
        
        let low: [String: Any] = ["quantity": 5]
        let exactly10: [String: Any] = ["quantity": 10]
        let high: [String: Any] = ["quantity": 15]
        
        XCTAssertTrue(evaluator.matches(object: low, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: exactly10, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: high, conditions: conditions))
    }
    
    func testNotEqualCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "status": ["$ne": "deleted"]
        ])
        
        let active: [String: Any] = ["status": "active"]
        let pending: [String: Any] = ["status": "pending"]
        let deleted: [String: Any] = ["status": "deleted"]
        
        XCTAssertTrue(evaluator.matches(object: active, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: pending, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: deleted, conditions: conditions))
    }
    
    // MARK: - Array Operators
    
    func testInArrayCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "role": ["$in": ["admin", "moderator"]]
        ])
        
        let admin: [String: Any] = ["role": "admin"]
        let moderator: [String: Any] = ["role": "moderator"]
        let user: [String: Any] = ["role": "user"]
        
        XCTAssertTrue(evaluator.matches(object: admin, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: moderator, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: user, conditions: conditions))
    }
    
    func testNotInArrayCondition() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "status": ["$nin": ["banned", "suspended"]]
        ])
        
        let active: [String: Any] = ["status": "active"]
        let pending: [String: Any] = ["status": "pending"]
        let banned: [String: Any] = ["status": "banned"]
        let suspended: [String: Any] = ["status": "suspended"]
        
        XCTAssertTrue(evaluator.matches(object: active, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: pending, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: banned, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: suspended, conditions: conditions))
    }
    
    // MARK: - Nested Conditions
    
    func testNestedObjectConditions() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "author": ["name": "John", "verified": true]
        ])
        
        let matching: [String: Any] = [
            "author": ["name": "John", "verified": true, "id": "123"]
        ]
        let wrongName: [String: Any] = [
            "author": ["name": "Jane", "verified": true]
        ]
        let notVerified: [String: Any] = [
            "author": ["name": "John", "verified": false]
        ]
        
        XCTAssertTrue(evaluator.matches(object: matching, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: wrongName, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: notVerified, conditions: conditions))
    }
    
    func testDeeplyNestedConditions() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "metadata": [
                "tags": ["$in": ["swift", "ios"]],
                "version": ["$gte": 2]
            ]
        ])
        
        let matching: [String: Any] = [
            "metadata": [
                "tags": "swift",
                "version": 3
            ]
        ]
        let wrongTag: [String: Any] = [
            "metadata": [
                "tags": "android",
                "version": 3
            ]
        ]
        let oldVersion: [String: Any] = [
            "metadata": [
                "tags": "ios",
                "version": 1
            ]
        ]
        
        XCTAssertTrue(evaluator.matches(object: matching, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: wrongTag, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: oldVersion, conditions: conditions))
    }
    
    // MARK: - Complex Logical Operators
    
    func testAndOperator() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "$and": [
                ["age": ["$gte": 18]],
                ["age": ["$lt": 65]]
            ]
        ])
        
        let adult: [String: Any] = ["age": 30]
        let teen: [String: Any] = ["age": 16]
        let senior: [String: Any] = ["age": 70]
        
        XCTAssertTrue(evaluator.matches(object: adult, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: teen, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: senior, conditions: conditions))
    }
    
    func testOrOperator() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "$or": [
                ["role": "admin"],
                ["department": "IT"]
            ]
        ])
        
        let admin: [String: Any] = ["role": "admin", "department": "Sales"]
        let itUser: [String: Any] = ["role": "user", "department": "IT"]
        let regularUser: [String: Any] = ["role": "user", "department": "Sales"]
        
        XCTAssertTrue(evaluator.matches(object: admin, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: itUser, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: regularUser, conditions: conditions))
    }
    
    func testNotOperator() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "$not": ["status": "inactive"]
        ])
        
        let active: [String: Any] = ["status": "active"]
        let pending: [String: Any] = ["status": "pending"]
        let inactive: [String: Any] = ["status": "inactive"]
        
        XCTAssertTrue(evaluator.matches(object: active, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: pending, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: inactive, conditions: conditions))
    }
    
    // MARK: - Edge Cases
    
    func testMissingFieldInObject() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions(["missingField": "value"])
        
        let object: [String: Any] = ["otherField": "data"]
        
        XCTAssertFalse(evaluator.matches(object: object, conditions: conditions))
    }
    
    func testNullValues() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions(["field": NSNull()])
        
        let withNull: [String: Any] = ["field": NSNull()]
        let withValue: [String: Any] = ["field": "value"]
        let withoutField: [String: Any] = ["otherField": "data"]
        
        XCTAssertTrue(evaluator.matches(object: withNull, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: withValue, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: withoutField, conditions: conditions))
    }
    
    func testEmptyConditions() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([:])
        
        let anyObject: [String: Any] = ["field": "value", "another": 123]
        
        // Empty conditions should match anything
        XCTAssertTrue(evaluator.matches(object: anyObject, conditions: conditions))
    }
    
    func testComplexMixedConditions() {
        let evaluator = BasicConditionEvaluator()
        let conditions = Conditions([
            "userId": "123",
            "age": ["$gte": 18],
            "role": ["$in": ["user", "moderator"]],
            "$or": [
                ["verified": true],
                ["yearsActive": ["$gt": 5]]
            ]
        ])
        
        let matching1: [String: Any] = [
            "userId": "123",
            "age": 25,
            "role": "user",
            "verified": true,
            "yearsActive": 2
        ]
        
        let matching2: [String: Any] = [
            "userId": "123",
            "age": 30,
            "role": "moderator",
            "verified": false,
            "yearsActive": 6
        ]
        
        let notMatching: [String: Any] = [
            "userId": "123",
            "age": 25,
            "role": "admin",  // Not in allowed roles
            "verified": true,
            "yearsActive": 3
        ]
        
        XCTAssertTrue(evaluator.matches(object: matching1, conditions: conditions))
        XCTAssertTrue(evaluator.matches(object: matching2, conditions: conditions))
        XCTAssertFalse(evaluator.matches(object: notMatching, conditions: conditions))
    }
    
    // MARK: - Field Validation
    
    func testFieldExtractor() {
        let extractor = FieldExtractor()
        
        let conditions = Conditions([
            "public.name": "value",
            "private.secret": "hidden",
            "metadata.tags": ["swift"]
        ])
        
        // Test extracting fields from conditions
        let fields = extractor.extractFields(from: conditions)
        XCTAssertTrue(fields.contains("public.name"))
        XCTAssertTrue(fields.contains("private.secret"))
        XCTAssertTrue(fields.contains("metadata.tags"))
    }
    
    func testNestedFieldExtraction() {
        let extractor = FieldExtractor()
        
        let conditions = Conditions([
            "$and": [
                ["user.name": "John"],
                ["user.email": ["$ne": NSNull()]]
            ],
            "$or": [
                ["status": "active"],
                ["role": ["$in": ["admin", "moderator"]]]
            ]
        ])
        
        let fields = extractor.extractFields(from: conditions)
        XCTAssertTrue(fields.contains("user.name"))
        XCTAssertTrue(fields.contains("user.email"))
        XCTAssertTrue(fields.contains("status"))
        XCTAssertTrue(fields.contains("role"))
    }
}