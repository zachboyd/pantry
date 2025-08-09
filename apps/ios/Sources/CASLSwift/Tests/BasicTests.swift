import XCTest
@testable import CASLSwift

final class BasicTests: XCTestCase {
    
    func testRuleCreation() {
        let rule = Rule(
            action: .read,
            subject: SubjectType("Post"),
            conditions: nil,
            inverted: false
        )
        
        XCTAssertEqual(rule.action, .read)
        XCTAssertEqual(rule.subject.value, "Post")
        XCTAssertFalse(rule.inverted)
        XCTAssertFalse(rule.hasConditions)
    }
    
    func testActionEquality() {
        let action1 = Action.create
        let action2 = Action("create")
        
        XCTAssertEqual(action1, action2)
        XCTAssertEqual(action1, "create")
    }
    
    func testSubjectTypeFromType() {
        struct TestSubject {}
        let subjectType = SubjectType.from(TestSubject.self)
        XCTAssertEqual(subjectType.value, "TestSubject")
    }
    
    func testRuleMatching() {
        let rule = Rule(action: .read, subject: SubjectType("Post"))
        
        XCTAssertTrue(rule.matches(action: .read, subjectType: SubjectType("Post")))
        XCTAssertFalse(rule.matches(action: .update, subjectType: SubjectType("Post")))
        XCTAssertFalse(rule.matches(action: .read, subjectType: SubjectType("User")))
    }
    
    func testManageActionMatchesAll() {
        let rule = Rule(action: .manage, subject: SubjectType("Post"))
        
        XCTAssertTrue(rule.matchesAction(.read))
        XCTAssertTrue(rule.matchesAction(.create))
        XCTAssertTrue(rule.matchesAction(.update))
        XCTAssertTrue(rule.matchesAction(.delete))
    }
    
    func testAllSubjectMatchesAll() {
        let rule = Rule(action: .read, subject: .all)
        
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("Post")))
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("User")))
        XCTAssertTrue(rule.matchesSubjectType(SubjectType("AnyType")))
    }
}