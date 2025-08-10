@testable import CASLSwift
import Combine
import SwiftUI
import XCTest

// Tests for Swift-specific integrations and features
final class SwiftIntegrationTests: XCTestCase {
    // MARK: - Sendable Conformance Tests

    func testSendableConformance() {
        // Test that core types conform to Sendable
        let rule = Rule(action: .read, subject: SubjectType("Post"))
        let action = Action.create
        let subjectType = SubjectType("User")
        let conditions = Conditions(["field": "value"])

        // These should all be Sendable
        Task {
            let _ = rule
            let _ = action
            let _ = subjectType
            let _ = conditions
        }

        XCTAssertNotNil(rule)
        XCTAssertNotNil(action)
        XCTAssertNotNil(subjectType)
        XCTAssertNotNil(conditions)
    }

    // MARK: - Type Safety Tests

    func testTypeSafeActions() {
        // Test that actions maintain type safety
        enum TypedAction: String {
            case create, read, update, delete, manage

            var action: Action {
                Action(rawValue)
            }
        }

        let createAction = TypedAction.create.action
        let readAction = TypedAction.read.action

        XCTAssertEqual(createAction.value, "create")
        XCTAssertEqual(readAction.value, "read")
        XCTAssertNotEqual(createAction, readAction)
    }

    func testTypeSafeSubjects() {
        // Test type-safe subject definitions
        enum AppSubject: String {
            case post = "Post"
            case comment = "Comment"
            case user = "User"

            var subjectType: SubjectType {
                SubjectType(rawValue)
            }
        }

        let postSubject = AppSubject.post.subjectType
        let commentSubject = AppSubject.comment.subjectType

        XCTAssertEqual(postSubject.value, "Post")
        XCTAssertEqual(commentSubject.value, "Comment")
        XCTAssertNotEqual(postSubject, commentSubject)
    }

    // MARK: - Builder Pattern Tests

    @MainActor
    func testBuilderPatternIntegration() async {
        let builder = PureAbilityBuilder()

        // Test fluent API
        builder
            .can("read", "Post")
            .can("create", "Comment")
            .cannot("delete", "User")

        let ability = await builder.build()

        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreateComment = await ability.can("create", "Comment")
        XCTAssertTrue(canCreateComment)
        let canDeleteUser = await ability.can("delete", "User")
        XCTAssertFalse(canDeleteUser)
    }

    // MARK: - Async/Await Tests

    @MainActor
    func testAsyncAbilityCreation() async {
        // Test async ability creation
        let builder = PureAbilityBuilder()
        builder.can("manage", "all")

        let ability = await builder.build()

        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canDeleteComment = await ability.can("delete", "Comment")
        XCTAssertTrue(canDeleteComment)
        let canUpdateUser = await ability.can("update", "User")
        XCTAssertTrue(canUpdateUser)
    }

    // MARK: - Subject Type Detection

    func testSwiftTypeDetection() {
        struct Post {
            let id: String
            let title: String
        }

        class User {
            let id: String
            init(id: String) { self.id = id }
        }

        let postType = detectSubjectType(of: Post(id: "1", title: "Test"))
        let userType = detectSubjectType(of: User(id: "1"))

        XCTAssertEqual(postType.value, "Post")
        XCTAssertEqual(userType.value, "User")
    }

    // MARK: - Rule Priority System

    @MainActor
    func testRulePriorityInSwift() async {
        let builder = PureAbilityBuilder()

        // Add rules with different priorities
        builder.can("read", "Post", priority: 10)
        builder.can("manage", "Post", priority: 100)
        builder.cannot("delete", "Post", priority: 50)

        let ability = await builder.build()

        // Can't access rules directly from PureAbility,
        // but we can verify through the builder
        let rules = builder.getRules()

        // Verify priority ordering
        XCTAssertTrue(rules.count >= 3)
        if rules.count >= 3 {
            // Rules should be sorted by priority (highest first)
            XCTAssertTrue(rules[0].priority >= rules[1].priority)
            XCTAssertTrue(rules[1].priority >= rules[2].priority)
        }
    }

    // MARK: - Collection Integration

    func testSwiftCollectionIntegration() {
        let rules = [
            Rule(action: .read, subject: SubjectType("Post")),
            Rule(action: .create, subject: SubjectType("Comment")),
            Rule(action: .delete, subject: SubjectType("User")),
        ]

        // Test filtering
        let readRules = rules.filter { $0.action == .read }
        XCTAssertEqual(readRules.count, 1)

        // Test mapping
        let actions = rules.map { $0.action.value }
        XCTAssertEqual(actions, ["read", "create", "delete"])

        // Test contains
        XCTAssertTrue(rules.contains { $0.subject.value == "Post" })
    }

    // MARK: - Error Handling

    @MainActor
    func testSwiftErrorHandling() async throws {
        // Test JSON parsing errors
        let invalidJSON = "{ invalid json"

        do {
            _ = try PermissionCoder.decodeRules(from: invalidJSON)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is PermissionError)
        }
    }

    // MARK: - String Interpolation

    func testStringInterpolationSupport() {
        let userId = "123"
        let householdId = "abc"

        let conditions = Conditions([
            "userId": "${userId}",
            "householdId": "${householdId}",
        ])

        // Verify conditions are stored correctly
        XCTAssertEqual(conditions.data["userId"] as? String, "${userId}")
        XCTAssertEqual(conditions.data["householdId"] as? String, "${householdId}")
    }
}
