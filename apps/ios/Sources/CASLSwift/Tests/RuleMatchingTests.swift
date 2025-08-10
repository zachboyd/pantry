@testable import CASLSwift
import XCTest

final class RuleMatchingTests: XCTestCase {
    // MARK: - Basic Rule Matching

    func testExactActionMatching() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))

        XCTAssertTrue(rule.matchesAction(.read))
        XCTAssertFalse(rule.matchesAction(.create))
        XCTAssertFalse(rule.matchesAction(.update))
        XCTAssertFalse(rule.matchesAction(.delete))
        XCTAssertFalse(rule.matchesAction(.manage))
    }

    func testManageActionMatchesAllActions() {
        let rule = Rule(action: .manage, subject: SubjectType("Post"))

        // manage should match all CRUD operations
        XCTAssertTrue(rule.matchesAction(.create))
        XCTAssertTrue(rule.matchesAction(.read))
        XCTAssertTrue(rule.matchesAction(.update))
        XCTAssertTrue(rule.matchesAction(.delete))
        XCTAssertTrue(rule.matchesAction(.manage))

        // Should also match custom actions
        XCTAssertTrue(rule.matchesAction(Action("publish")))
        XCTAssertTrue(rule.matchesAction(Action("archive")))
    }

    func testSubjectTypeMatching() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))

        XCTAssertTrue(rule.matchesSubjectType(SubjectType("Post")))
        XCTAssertFalse(rule.matchesSubjectType(SubjectType("User")))
        XCTAssertFalse(rule.matchesSubjectType(SubjectType("Comment")))
        XCTAssertFalse(rule.matchesSubjectType(.all))
    }

    func testAllSubjectMatchesEverything() {
        let rule = Rule(action: .read, subject: .all)

        XCTAssertTrue(rule.matchesSubjectType(SubjectType("Post")))
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("User")))
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("AnyCustomType")))
        XCTAssertTrue(rule.matchesSubjectType(.all))
    }

    func testInvertedRuleMatching() {
        let rule = Rule(action: .delete, subject: SubjectType("Post"), inverted: true)

        // Inverted rule should NOT match
        XCTAssertFalse(rule.matches(action: .delete, subjectType: SubjectType("Post")))

        // But the base matching logic should still work
        XCTAssertTrue(rule.matchesAction(.delete))
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("Post")))
    }

    // MARK: - Field-Based Matching

    func testFieldRestrictions() {
        let rule = Rule(
            action: .update,
            subject: SubjectType("User"),
            fields: ["name", "email"]
        )

        XCTAssertTrue(rule.hasFieldRestrictions)
        XCTAssertEqual(rule.fields?.count, 2)
        XCTAssertTrue(rule.fields?.contains("name") ?? false)
        XCTAssertTrue(rule.fields?.contains("email") ?? false)
        XCTAssertFalse(rule.fields?.contains("password") ?? false)
    }

    func testRuleWithoutFields() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))

        XCTAssertFalse(rule.hasFieldRestrictions)
        XCTAssertNil(rule.fields)
    }

    // MARK: - Priority-Based Matching

    func testRulePriority() {
        let lowPriorityRule = Rule(
            action: .read,
            subject: SubjectType("Post"),
            priority: 0
        )

        let highPriorityRule = Rule(
            action: .read,
            subject: SubjectType("Post"),
            priority: 100
        )

        XCTAssertEqual(lowPriorityRule.priority, 0)
        XCTAssertEqual(highPriorityRule.priority, 100)

        // Priority doesn't affect matching, only ordering
        XCTAssertTrue(lowPriorityRule.matches(action: .read, subjectType: SubjectType("Post")))
        XCTAssertTrue(highPriorityRule.matches(action: .read, subjectType: SubjectType("Post")))
    }

    func testDefaultPriority() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))
        XCTAssertEqual(rule.priority, 0)
    }

    // MARK: - Complex Rule Matching

    func testRuleWithReason() {
        let rule = Rule(
            action: .delete,
            subject: SubjectType("Post"),
            reason: "Only admins can delete posts"
        )

        XCTAssertEqual(rule.reason, "Only admins can delete posts")
        XCTAssertTrue(rule.matches(action: .delete, subjectType: SubjectType("Post")))
    }

    func testMultipleRuleInteraction() {
        let rules = [
            Rule(action: .read, subject: .all), // Allow read on everything
            Rule(action: .manage, subject: SubjectType("Admin")), // Allow manage on Admin
            Rule(action: .delete, subject: SubjectType("Post"), inverted: true), // Deny delete on Post
        ]

        // Test first rule
        XCTAssertTrue(rules[0].matches(action: .read, subjectType: SubjectType("AnyType")))

        // Test second rule
        XCTAssertTrue(rules[1].matches(action: .create, subjectType: SubjectType("Admin")))
        XCTAssertTrue(rules[1].matches(action: .delete, subjectType: SubjectType("Admin")))

        // Test third rule (inverted)
        XCTAssertFalse(rules[2].matches(action: .delete, subjectType: SubjectType("Post")))
    }

    // MARK: - Case Sensitivity

    func testActionCaseInsensitivity() {
        let rule = Rule(action: Action("READ"), subject: SubjectType("Post"))

        // Actions should be case-insensitive
        XCTAssertTrue(rule.matchesAction(Action("read")))
        XCTAssertTrue(rule.matchesAction(Action("READ")))
        XCTAssertTrue(rule.matchesAction(Action("Read")))
    }

    func testSubjectTypeCaseSensitivity() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))

        // Subject types are case-sensitive
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("Post")))
        XCTAssertFalse(rule.matchesSubjectType(SubjectType("post")))
        XCTAssertFalse(rule.matchesSubjectType(SubjectType("POST")))
    }

    // MARK: - Edge Cases

    func testEmptyActionString() {
        let rule = Rule(action: Action(""), subject: SubjectType("Post"))
        XCTAssertEqual(rule.action.value, "")
        XCTAssertTrue(rule.matchesAction(Action("")))
        XCTAssertFalse(rule.matchesAction(.read))
    }

    func testEmptySubjectString() {
        let rule = Rule(action: .read, subject: SubjectType(""))
        XCTAssertEqual(rule.subject.value, "")
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("")))
        XCTAssertFalse(rule.matchesSubjectType(SubjectType("Post")))
    }

    func testRuleEquality() {
        let rule1 = Rule(action: .read, subject: SubjectType("Post"))
        let rule2 = Rule(action: .read, subject: SubjectType("Post"))
        let rule3 = Rule(action: .update, subject: SubjectType("Post"))

        // Rules with same properties should be considered equal
        XCTAssertEqual(rule1.action, rule2.action)
        XCTAssertEqual(rule1.subject, rule2.subject)
        XCTAssertNotEqual(rule1.action, rule3.action)
    }
}
