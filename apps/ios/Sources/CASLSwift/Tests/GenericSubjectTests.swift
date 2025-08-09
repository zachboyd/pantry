import XCTest
@testable import CASLSwift

final class GenericSubjectTests: XCTestCase {
    
    // MARK: - Test Types
    
    struct TestProperties: Sendable {
        let name: String
        let value: Int
        let isActive: Bool
    }
    
    struct ComplexProperties: Sendable {
        let title: String
        let metadata: [String: String]
        let scores: [Double]
    }
    
    // MARK: - GenericSubject Tests
    
    func testGenericSubjectCreation() {
        let properties = TestProperties(name: "Test", value: 42, isActive: true)
        let subject = GenericSubject(properties)
        
        XCTAssertEqual(subject.properties.name, "Test")
        XCTAssertEqual(subject.properties.value, 42)
        XCTAssertEqual(subject.properties.isActive, true)
        XCTAssertEqual(subject.subjectType.value, "TestProperties")
    }
    
    func testGenericSubjectWithCustomType() {
        let properties = TestProperties(name: "Test", value: 42, isActive: true)
        let subject = GenericSubject(properties, subjectType: "CustomType")
        
        XCTAssertEqual(subject.subjectType.value, "CustomType")
    }
    
    func testGenericSubjectDynamicMemberLookup() {
        let properties = TestProperties(name: "Dynamic", value: 100, isActive: false)
        let subject = GenericSubject(properties)
        
        // Access via dynamic member lookup
        let name: String = subject[dynamicMember: \.name]
        let value: Int = subject[dynamicMember: \.value]
        let isActive: Bool = subject[dynamicMember: \.isActive]
        
        XCTAssertEqual(name, "Dynamic")
        XCTAssertEqual(value, 100)
        XCTAssertEqual(isActive, false)
    }
    
    // MARK: - IdentifiableGenericSubject Tests
    
    func testIdentifiableGenericSubjectWithStringID() {
        let properties = TestProperties(name: "Identifiable", value: 99, isActive: true)
        let subject = StringIdentifiableSubject(
            id: "test-id",
            properties: properties,
            subjectType: "TestSubject"
        )
        
        XCTAssertEqual(subject.id, "test-id")
        XCTAssertEqual(subject.properties.name, "Identifiable")
        XCTAssertEqual(subject.subjectType.value, "TestSubject")
    }
    
    func testIdentifiableGenericSubjectWithUUID() {
        let uuid = UUID()
        let properties = ComplexProperties(
            title: "Complex",
            metadata: ["key": "value"],
            scores: [1.0, 2.0, 3.0]
        )
        let subject = UUIDIdentifiableSubject(
            id: uuid,
            properties: properties,
            subjectType: "ComplexSubject"
        )
        
        XCTAssertEqual(subject.id, uuid)
        XCTAssertEqual(subject.properties.title, "Complex")
        XCTAssertEqual(subject.properties.metadata["key"], "value")
        XCTAssertEqual(subject.properties.scores, [1.0, 2.0, 3.0])
    }
    
    func testIdentifiableGenericSubjectWithIntID() {
        let properties = TestProperties(name: "IntID", value: 77, isActive: false)
        let subject = IntIdentifiableSubject(
            id: 12345,
            properties: properties
        )
        
        XCTAssertEqual(subject.id, 12345)
        XCTAssertEqual(subject.properties.name, "IntID")
        XCTAssertEqual(subject.subjectType.value, "TestProperties")
    }
    
    // MARK: - SimpleSubject Tests
    
    func testSimpleSubjectCreation() {
        let subject = SimpleSubject(type: "Article", id: "article-1")
        
        XCTAssertEqual(subject.subjectType.value, "Article")
        XCTAssertEqual(subject.id, "article-1")
        XCTAssertNil(subject.properties)
    }
    
    func testSimpleSubjectWithProperties() {
        let props: [String: Any] = [
            "title": "Test Article",
            "published": true,
            "views": 1000
        ]
        let subject = SimpleSubject(type: "Article", id: "article-2", properties: props)
        
        XCTAssertEqual(subject.subjectType.value, "Article")
        XCTAssertEqual(subject.id, "article-2")
        XCTAssertNotNil(subject.properties)
        XCTAssertEqual(subject.properties?["title"] as? String, "Test Article")
        XCTAssertEqual(subject.properties?["published"] as? Bool, true)
        XCTAssertEqual(subject.properties?["views"] as? Int, 1000)
    }
    
    // MARK: - SubjectFactory Tests
    
    func testSubjectFactorySimple() {
        let subject = SubjectFactory.simple(type: "Product")
        XCTAssertEqual(subject.subjectType.value, "Product")
        XCTAssertNil(subject.id)
    }
    
    func testSubjectFactorySimpleWithID() {
        let subject = SubjectFactory.simple(type: "Product", id: "prod-1")
        XCTAssertEqual(subject.subjectType.value, "Product")
        XCTAssertEqual(subject.id, "prod-1")
    }
    
    func testSubjectFactoryGeneric() {
        let properties = TestProperties(name: "Factory", value: 55, isActive: true)
        let subject = SubjectFactory.generic(properties, type: "FactorySubject")
        
        XCTAssertEqual(subject.properties.name, "Factory")
        XCTAssertEqual(subject.subjectType.value, "FactorySubject")
    }
    
    func testSubjectFactoryIdentifiable() {
        let properties = TestProperties(name: "ID Factory", value: 88, isActive: false)
        let subject = SubjectFactory.identifiable(
            id: "factory-id",
            properties: properties,
            type: "IDFactorySubject"
        )
        
        XCTAssertEqual(subject.id, "factory-id")
        XCTAssertEqual(subject.properties.name, "ID Factory")
        XCTAssertEqual(subject.subjectType.value, "IDFactorySubject")
    }
    
    // MARK: - FluentBuilder Tests
    
    func testFluentSubjectBuilder() {
        let properties = TestProperties(name: "Fluent", value: 33, isActive: true)
        let subject = SubjectFactory.build(properties)
            .withType("FluentSubject")
            .build()
        
        XCTAssertEqual(subject.properties.name, "Fluent")
        XCTAssertEqual(subject.subjectType.value, "FluentSubject")
    }
    
    func testFluentIdentifiableSubjectBuilder() {
        let properties = ComplexProperties(
            title: "Fluent ID",
            metadata: ["builder": "test"],
            scores: [9.5, 8.7]
        )
        let subject = SubjectFactory.build(id: "fluent-123", properties: properties)
            .withType("FluentIDSubject")
            .build()
        
        XCTAssertEqual(subject.id, "fluent-123")
        XCTAssertEqual(subject.properties.title, "Fluent ID")
        XCTAssertEqual(subject.subjectType.value, "FluentIDSubject")
    }
    
    // MARK: - Convenience Function Tests
    
    func testMakeSubjectFunction() {
        let properties = TestProperties(name: "Make", value: 11, isActive: true)
        let subject = makeSubject(properties, type: "MadeSubject")
        
        XCTAssertEqual(subject.properties.name, "Make")
        XCTAssertEqual(subject.subjectType.value, "MadeSubject")
    }
    
    func testMakeIdentifiableSubjectFunction() {
        let properties = TestProperties(name: "Make ID", value: 22, isActive: false)
        let subject = makeIdentifiableSubject(
            id: 999,
            properties: properties,
            type: "MadeIDSubject"
        )
        
        XCTAssertEqual(subject.id, 999)
        XCTAssertEqual(subject.properties.name, "Make ID")
        XCTAssertEqual(subject.subjectType.value, "MadeIDSubject")
    }
    
    // MARK: - Integration with Ability Tests
    
    func testGenericSubjectWithAbility() async {
        // Create a generic subject
        let userProps = TestProperties(name: "John", value: 1, isActive: true)
        let user = StringIdentifiableSubject(
            id: "user-1",
            properties: userProps,
            subjectType: "User"
        )
        
        // Create ability that allows reading users
        let ability = await PureAbilityBuilder()
            .can("read", "User")
            .can("update", "User", ["id": "user-1"])
            .build()
        
        // Test permissions
        let canReadUser = await ability.can("read", user)
        XCTAssertTrue(canReadUser)
        
        // Test update with conditions directly (no wrapping needed)
        let canUpdateUser = await ability.can("update", user)
        XCTAssertTrue(canUpdateUser)
    }
    
    func testSimpleSubjectWithAbility() async {
        let article = SimpleSubject(
            type: "Article",
            id: "article-1",
            properties: ["published": true]
        )
        
        let ability = await PureAbilityBuilder()
            .can("read", "Article")
            .can("delete", "Article", ["id": "article-1"])
            .build()
        
        let canReadArticle = await ability.can("read", article)
        XCTAssertTrue(canReadArticle)
        
        // Test delete with conditions directly (no wrapping needed)
        let canDeleteArticle = await ability.can("delete", article)
        XCTAssertTrue(canDeleteArticle)
    }
    
    // MARK: - Performance Tests
    
    func testGenericSubjectPerformance() {
        measure {
            for i in 0..<1000 {
                let properties = TestProperties(
                    name: "Perf \(i)",
                    value: i,
                    isActive: i % 2 == 0
                )
                _ = GenericSubject(properties, subjectType: "PerfTest")
            }
        }
    }
    
    func testIdentifiableGenericSubjectPerformance() {
        measure {
            for i in 0..<1000 {
                let properties = TestProperties(
                    name: "Perf \(i)",
                    value: i,
                    isActive: i % 2 == 0
                )
                _ = StringIdentifiableSubject(
                    id: "perf-\(i)",
                    properties: properties,
                    subjectType: "PerfTest"
                )
            }
        }
    }
}