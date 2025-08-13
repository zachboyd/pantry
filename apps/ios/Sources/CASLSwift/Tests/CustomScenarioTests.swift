@testable import CASLSwift
import XCTest

// MARK: - Generic Subject Type Aliases for Testing

// Empty properties for subjects that only need an ID
struct EmptyProperties: Sendable {}

typealias GenericTestUser = StringIdentifiableSubject<EmptyProperties>
typealias GenericTestHousehold = StringIdentifiableSubject<EmptyProperties>

// MARK: - Test-Specific Typed Enums (Mirroring JeevesKit Structure)

/// Test actions that mirror JeevesAction from the app
enum TestAction: String, CaseIterable {
    case create
    case read
    case update
    case delete
    case manage // Special action meaning all actions
}

/// Test subjects that mirror JeevesSubject from the app
enum TestSubject: String {
    case user = "User"
    case household = "Household"
    case householdMember = "HouseholdMember"
    case message = "Message"
    case pantry = "Pantry"
    case all // Special subject meaning all subjects
}

/// Type alias for our test-specific typed ability
typealias TestAbility = Ability<TestAction, TestSubject>

// MARK: - Supporting Types

final class CustomScenarioTests: XCTestCase {
    func testHouseholdOwnerAccess() async throws {
        let json = """
                            [
                            [
                                "read",
                                "User",
                                {
                                "id": "627764e6-cf8b-4abe-b92c-016cc87bea82"
                                }
                            ],
                            [
                                "create",
                                "Household"
                            ],
                            [
                                "update",
                                "User",
                                {
                                "id": "627764e6-cf8b-4abe-b92c-016cc87bea82"
                                }
                            ],
                            [
                                "update",
                                "User",
                                {
                                "id": {
                                    "$in": [
                                    "07127d4d-a47f-479b-8067-9c9a3f9dc437"
                                    ]
                                }
                                }
                            ],
                            [
                                "manage",
                                "Household",
                                {
                                "id": {
                                    "$in": [
                                    "569b66f6-d931-40f3-9e53-b35e4b71a334"
                                    ]
                                }
                                }
                            ],
                            [
                                "manage",
                                "HouseholdMember",
                                {
                                "role": {
                                    "$ne": "manager"
                                },
                                "household_id": {
                                    "$in": [
                                    "569b66f6-d931-40f3-9e53-b35e4b71a334"
                                    ]
                                }
                                }
                            ],
                            [
                                "read",
                                "HouseholdMember",
                                {
                                "household_id": {
                                    "$in": [
                                    "569b66f6-d931-40f3-9e53-b35e4b71a334"
                                    ]
                                }
                                }
                            ],
                            [
                                "manage",
                                "Message",
                                {
                                "household_id": {
                                    "$in": [
                                    "569b66f6-d931-40f3-9e53-b35e4b71a334"
                                    ]
                                }
                                }
                            ],
                            [
                                "read",
                                "User",
                                {
                                "id": {
                                    "$in": [
                                    "627764e6-cf8b-4abe-b92c-016cc87bea82",
                                    "07127d4d-a47f-479b-8067-9c9a3f9dc437"
                                    ]
                                }
                                }
                            ]
                            ]
        """

        // CASLSwift now natively supports the CASL array format
        let data = json.data(using: .utf8)!
        let ability = try await PureAbility.from(json: data)

        // Check permission for own user (should be allowed)
        let ownUser = GenericTestUser(
            id: "627764e6-cf8b-4abe-b92c-016cc87bea82",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let readOwnUser = await ability.can("read", ownUser)
        XCTAssertTrue(readOwnUser)

        // Check permission for random user (should be denied)
        let randomUser = GenericTestUser(
            id: "random-user-id",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let readRandomUser = await ability.can("read", randomUser)
        XCTAssertFalse(readRandomUser)

        // Also test with a second allowed user to make sure conditions work
        let allowedUser2 = GenericTestUser(
            id: "07127d4d-a47f-479b-8067-9c9a3f9dc437",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let readAllowedUser2 = await ability.can("read", allowedUser2)
        XCTAssertTrue(readAllowedUser2)

        // Additional test: check if "create Household" works (no conditions)
        let canCreateHousehold = await ability.can("create", "Household")
        XCTAssertTrue(canCreateHousehold)

        // Test managing a specific household using factory pattern for even simpler syntax
        let household = SubjectFactory.simple(
            type: "Household",
            id: "569b66f6-d931-40f3-9e53-b35e4b71a334"
        )
        let canManageHousehold = await ability.can("manage", household)
        XCTAssertTrue(canManageHousehold)
        let canUpdateHousehold = await ability.can("update", household)
        XCTAssertTrue(canUpdateHousehold)
        let canDeleteHousehold = await ability.can("delete", household)
        XCTAssertTrue(canDeleteHousehold)

        // managing household members
        let householdMember = SubjectFactory.simple(
            type: "HouseholdMember",
            properties: [
                "household_id": "569b66f6-d931-40f3-9e53-b35e4b71a334",
            ]
        )
        let canCreateHouseholdMember = await ability.can("create", householdMember)
        XCTAssertTrue(canCreateHouseholdMember)

        let canManageHouseholdMember = await ability.can("manage", householdMember)
        XCTAssertTrue(canManageHouseholdMember)

        // Test managing a different household (should fail)
        let otherHousehold = SubjectFactory.simple(
            type: "Household",
            id: "different-household-id"
        )
        let canManageOtherHousehold = await ability.can("manage", otherHousehold)
        XCTAssertFalse(canManageOtherHousehold)
    }

    // MARK: - Typed Ability Tests

    func testTypedAbilityWithJeevesScenario() async throws {
        // Build typed ability using AbilityBuilder directly
        let builder = AbilityBuilder<TestAction, TestSubject>()

        // Add rules with typed enums
        builder.can(TestAction.read, TestSubject.user, ["id": "627764e6-cf8b-4abe-b92c-016cc87bea82"])
        builder.can(TestAction.create, TestSubject.household)
        builder.can(TestAction.update, TestSubject.user, ["id": "627764e6-cf8b-4abe-b92c-016cc87bea82"])
        builder.can(TestAction.manage, TestSubject.household, ["id": ["$in": ["569b66f6-d931-40f3-9e53-b35e4b71a334"]]])
        builder.can(TestAction.manage, TestSubject.householdMember, [
            "role": ["$ne": "manager"],
            "household_id": ["$in": ["569b66f6-d931-40f3-9e53-b35e4b71a334"]],
        ])
        builder.can(TestAction.read, TestSubject.householdMember, ["household_id": ["$in": ["569b66f6-d931-40f3-9e53-b35e4b71a334"]]])
        builder.can(TestAction.manage, TestSubject.message, ["household_id": ["$in": ["569b66f6-d931-40f3-9e53-b35e4b71a334"]]])

        let ability = await builder.build()

        // Now test with typed enums - compile-time safety!

        // Test 1: Can read own user
        let ownUser = StringIdentifiableSubject<EmptyProperties>(
            id: "627764e6-cf8b-4abe-b92c-016cc87bea82",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let canReadOwnUser = await ability.can(TestAction.read, ownUser)
        XCTAssertTrue(canReadOwnUser, "Should be able to read own user")

        // Test 2: Cannot read random user
        let randomUser = StringIdentifiableSubject<EmptyProperties>(
            id: "random-user-id",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let canReadRandomUser = await ability.can(TestAction.read, randomUser)
        XCTAssertFalse(canReadRandomUser, "Should not be able to read random user")

        // Test 3: Can create household (no conditions)
        let canCreateHousehold = await ability.can(TestAction.create, TestSubject.household)
        XCTAssertTrue(canCreateHousehold, "Should be able to create household")

        // Test 4: Can manage specific household
        let household = StringIdentifiableSubject<EmptyProperties>(
            id: "569b66f6-d931-40f3-9e53-b35e4b71a334",
            properties: EmptyProperties(),
            subjectType: "Household"
        )
        let canManageHousehold = await ability.can(TestAction.manage, household)
        XCTAssertTrue(canManageHousehold, "Should be able to manage specific household")

        // Test 5: All manage permissions include CRUD
        let canUpdateHousehold = await ability.can(TestAction.update, household)
        XCTAssertTrue(canUpdateHousehold, "Manage permission should include update")

        let canDeleteHousehold = await ability.can(TestAction.delete, household)
        XCTAssertTrue(canDeleteHousehold, "Manage permission should include delete")

        // Test 6: Cannot manage different household
        let otherHousehold = StringIdentifiableSubject<EmptyProperties>(
            id: "different-household-id",
            properties: EmptyProperties(),
            subjectType: "Household"
        )
        let canManageOtherHousehold = await ability.can(TestAction.manage, otherHousehold)
        XCTAssertFalse(canManageOtherHousehold, "Should not be able to manage different household")

        // Test 7: Async API works as expected
        // The ability is properly initialized after await builder.build()
        // All permission checks should work correctly

        // Additional test - check that "manage" includes all CRUD operations
        XCTAssertTrue(canManageHousehold, "Should be able to manage household (includes all operations)")
        XCTAssertTrue(canUpdateHousehold, "Manage should include update")
        XCTAssertTrue(canDeleteHousehold, "Manage should include delete")
    }

    func testTypedAbilityConversionFromBackend() async throws {
        // Simulate backend response with permission rules
        let backendPermissions = [
            ["action": "read", "subject": "User", "conditions": ["id": "user-123"]],
            ["action": "update", "subject": "User", "conditions": ["id": "user-123"]],
            ["action": ["create", "read"], "subject": "Household"],
            ["action": "manage", "subject": "HouseholdMember", "conditions": ["household_id": "house-456"]],
            ["action": "delete", "subject": "Message", "inverted": true, "conditions": ["author_id": ["$ne": "user-123"]]],
        ]

        // Convert to typed ability
        let builder = AbilityBuilder<TestAction, TestSubject>()

        for permission in backendPermissions {
            // Extract and validate actions
            let actions: [TestAction]
            if let singleAction = permission["action"] as? String,
               let action = TestAction(rawValue: singleAction)
            {
                actions = [action]
            } else if let multipleActions = permission["action"] as? [String] {
                actions = multipleActions.compactMap { TestAction(rawValue: $0) }
            } else {
                continue
            }

            // Extract and validate subject
            guard let subjectString = permission["subject"] as? String,
                  let subject = TestSubject(rawValue: subjectString)
            else {
                continue
            }

            // Extract conditions and inverted flag
            let conditions = permission["conditions"] as? [String: Any]
            let inverted = permission["inverted"] as? Bool ?? false

            // Add rules
            for action in actions {
                if inverted {
                    if let conditions = conditions {
                        builder.cannot(action, subject, conditions)
                    } else {
                        builder.cannot(action, subject)
                    }
                } else {
                    if let conditions = conditions {
                        builder.can(action, subject, conditions)
                    } else {
                        builder.can(action, subject)
                    }
                }
            }
        }

        let ability = await builder.build()

        // Test the converted ability

        // Test user permissions
        let user = StringIdentifiableSubject<EmptyProperties>(
            id: "user-123",
            properties: EmptyProperties(),
            subjectType: "User"
        )
        let canReadUser = await ability.can(TestAction.read, user)
        XCTAssertTrue(canReadUser, "Can read own user")
        let canUpdateUser = await ability.can(TestAction.update, user)
        XCTAssertTrue(canUpdateUser, "Can update own user")
        let canDeleteUser = await ability.can(TestAction.delete, user)
        XCTAssertFalse(canDeleteUser, "Cannot delete user (no permission)")

        // Test household permissions (no conditions)
        let canCreateHousehold = await ability.can(TestAction.create, TestSubject.household)
        XCTAssertTrue(canCreateHousehold, "Can create household")
        let canReadHousehold = await ability.can(TestAction.read, TestSubject.household)
        XCTAssertTrue(canReadHousehold, "Can read household")
        let canDeleteHousehold = await ability.can(TestAction.delete, TestSubject.household)
        XCTAssertFalse(canDeleteHousehold, "Cannot delete household")

        // Test household member with conditions
        let member = SubjectFactory.simple(
            type: "HouseholdMember",
            properties: ["household_id": "house-456"]
        )
        let canManageMember = await ability.can(TestAction.manage, member)
        XCTAssertTrue(canManageMember, "Can manage member in specific household")

        let wrongMember = SubjectFactory.simple(
            type: "HouseholdMember",
            properties: ["household_id": "wrong-house"]
        )
        let canManageWrongMember = await ability.can(TestAction.manage, wrongMember)
        XCTAssertFalse(canManageWrongMember, "Cannot manage member in different household")

        // Test inverted rule (cannot delete messages from other authors)
        let otherMessage = SubjectFactory.simple(
            type: "Message",
            properties: ["author_id": "other-user"]
        )
        let canDeleteOtherMessage = await ability.can(TestAction.delete, otherMessage)
        XCTAssertFalse(canDeleteOtherMessage, "Cannot delete message from other author")

        let ownMessage = SubjectFactory.simple(
            type: "Message",
            properties: ["author_id": "user-123"]
        )
        let canDeleteOwnMessage = await ability.can(TestAction.delete, ownMessage)
        // The inverted rule says "cannot delete messages where author_id != user-123"
        // So we CAN delete messages where author_id == user-123
        // But since we don't have a positive "can delete" rule, this should actually be false
        XCTAssertFalse(canDeleteOwnMessage, "Cannot delete own message without explicit permission")
    }

    func testTypedAbilityVsPureAbilityComparison() async throws {
        // This test demonstrates the key differences between typed and untyped abilities

        let rules = [
            Rule(action: Action("manage"), subject: SubjectType("Household")),
            Rule(action: Action("read"), subject: SubjectType("User")),
        ]

        // Create PureAbility (string-based)
        let pureAbility = await PureAbility.create(rules: rules)

        // Create typed Ability
        let typedBuilder = AbilityBuilder<TestAction, TestSubject>()
        typedBuilder.can(TestAction.manage, TestSubject.household)
        typedBuilder.can(TestAction.read, TestSubject.user)
        let typedAbility = await typedBuilder.build()

        // With PureAbility, we use strings (runtime checking)
        let pureCanManage = await pureAbility.can("manage", "Household")
        XCTAssertTrue(pureCanManage)
        let pureCanRead = await pureAbility.can("read", "User")
        XCTAssertTrue(pureCanRead)

        // Typos are not caught at compile time with PureAbility
        // This would compile but fail at runtime:
        let typoResult = await pureAbility.can("raed", "User") // Typo!
        XCTAssertFalse(typoResult, "Typo in action string results in false")

        // With typed Ability, we use enums (compile-time safety)
        let typedCanManage = await typedAbility.can(TestAction.manage, TestSubject.household)
        XCTAssertTrue(typedCanManage)
        let typedCanRead = await typedAbility.can(TestAction.read, TestSubject.user)
        XCTAssertTrue(typedCanRead)

        // This would NOT compile (compile-time safety):
        // let result = await typedAbility.can(.raed, .user) // Compiler error!

        // Typed ability also provides better IDE support with autocomplete
        // and prevents invalid action/subject combinations at compile time
    }
}
