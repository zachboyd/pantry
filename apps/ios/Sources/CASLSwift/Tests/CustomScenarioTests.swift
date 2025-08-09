@testable import CASLSwift
import XCTest

// MARK: - Generic Subject Type Aliases for Testing

// Empty properties for subjects that only need an ID
struct EmptyProperties: Sendable {}

typealias GenericTestUser = StringIdentifiableSubject<EmptyProperties>
typealias GenericTestHousehold = StringIdentifiableSubject<EmptyProperties>

// MARK: - Supporting Types

final class CustomScenarioTests: XCTestCase {
    func testHouseholdOwnerAccess() async throws {
        let json = """
            [
            [
                "read",
                "User",
                {
                "id": "35ab9f64-b9bd-40ef-8a3a-720a5cd619b1"
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
                "id": "35ab9f64-b9bd-40ef-8a3a-720a5cd619b1"
                }
            ],
            [
                "update",
                "User",
                {
                "id": {
                    "$in": [
                    "046bc4fb-db31-4cef-b0f4-70530b91d7aa"
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
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
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
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
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
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
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
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
                    ]
                }
                }
            ],
            [
                "manage",
                "Pantry",
                {
                "household_id": {
                    "$in": [
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
                    ]
                }
                }
            ],
            [
                "read",
                "Pantry",
                {
                "household_id": {
                    "$in": [
                    "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
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
                    "35ab9f64-b9bd-40ef-8a3a-720a5cd619b1",
                    "046bc4fb-db31-4cef-b0f4-70530b91d7aa"
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
            id: "35ab9f64-b9bd-40ef-8a3a-720a5cd619b1",
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
            id: "046bc4fb-db31-4cef-b0f4-70530b91d7aa",
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
            id: "90eefd4d-1784-4113-b5a6-c0dcb4c7fb14"
        )
        let canManageHousehold = await ability.can("manage", household)
        XCTAssertTrue(canManageHousehold)
        let canUpdateHousehold = await ability.can("update", household)
        XCTAssertTrue(canUpdateHousehold)
        let canDeleteHousehold = await ability.can("delete", household)
        XCTAssertTrue(canDeleteHousehold)

        // Test managing a different household (should fail)
        let otherHousehold = SubjectFactory.simple(
            type: "Household",
            id: "different-household-id"
        )
        let canManageOtherHousehold = await ability.can("manage", otherHousehold)
        XCTAssertFalse(canManageOtherHousehold)
    }
}
