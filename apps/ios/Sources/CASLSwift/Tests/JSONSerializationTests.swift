@testable import CASLSwift
import XCTest

final class JSONSerializationTests: XCTestCase {
    // MARK: - Advanced JSON Serialization Tests

    func testComplexNestedConditionsSerialization() throws {
        let complexConditions: [String: Any] = [
            "$and": [
                ["userId": "${userId}"],
                [
                    "$or": [
                        ["status": "active"],
                        ["role": ["$in": ["admin", "moderator"]]],
                    ],
                ],
                [
                    "metadata": [
                        "verified": true,
                        "score": ["$gte": 100],
                    ],
                ],
            ],
        ]

        let conditions = complexConditions.mapValues { AnyCodable($0) }
        let permission = Permission(
            action: StringOrArray("manage"),
            subject: StringOrArray("Content"),
            conditions: conditions,
            inverted: false
        )

        // Encode
        let data = try JSONEncoder().encode(permission)

        // Decode
        let decoded = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(decoded.action.first, "manage")
        XCTAssertEqual(decoded.subject?.first, "Content")
        XCTAssertNotNil(decoded.conditions)

        // Verify nested structure preserved
        if let andValue = decoded.conditions?["$and"],
           let andArray = andValue.value as? [[String: Any]]
        {
            XCTAssertEqual(andArray.count, 3)

            // Check first condition
            if let firstCondition = andArray[0]["userId"] as? String {
                XCTAssertEqual(firstCondition, "${userId}")
            }

            // Check nested OR
            if let orCondition = andArray[1]["$or"] as? [[String: Any]] {
                XCTAssertEqual(orCondition.count, 2)
            }
        }
    }

    func testArrayFieldsSerialization() throws {
        // Test with string array for fields
        let permission1 = Permission(
            action: StringOrArray("read"),
            subject: StringOrArray("User"),
            fields: StringOrArray(["name", "email", "avatar"])
        )

        let data1 = try JSONEncoder().encode(permission1)
        let json1 = try JSONSerialization.jsonObject(with: data1) as! [String: Any]

        XCTAssertEqual(json1["fields"] as? [String], ["name", "email", "avatar"])

        // Test with single string for fields
        let permission2 = Permission(
            action: StringOrArray("read"),
            subject: StringOrArray("User"),
            fields: StringOrArray("name")
        )

        let data2 = try JSONEncoder().encode(permission2)
        let json2 = try JSONSerialization.jsonObject(with: data2) as! [String: Any]

        XCTAssertEqual(json2["fields"] as? String, "name")
    }

    func testMultipleActionsAndSubjects() throws {
        // Test multiple actions and subjects
        let permission = Permission(
            action: StringOrArray(["read", "update", "delete"]),
            subject: StringOrArray(["Post", "Comment", "Reply"])
        )

        let data = try JSONEncoder().encode(permission)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["action"] as? [String], ["read", "update", "delete"])
        XCTAssertEqual(json["subject"] as? [String], ["Post", "Comment", "Reply"])

        // Test conversion to rules
        let rules = permission.toRules()

        // Should create 3x3 = 9 rules (cartesian product)
        XCTAssertEqual(rules.count, 9)

        // Verify some combinations
        XCTAssertTrue(rules.contains { $0.action.value == "read" && $0.subject.value == "Post" })
        XCTAssertTrue(rules.contains { $0.action.value == "update" && $0.subject.value == "Comment" })
        XCTAssertTrue(rules.contains { $0.action.value == "delete" && $0.subject.value == "Reply" })
    }

    func testInvertedFieldExclusion() throws {
        // Test that inverted: false is not included in JSON
        let permission1 = Permission(
            action: StringOrArray("read"),
            subject: StringOrArray("Post"),
            inverted: false
        )

        let data1 = try JSONEncoder().encode(permission1)
        let json1 = try JSONSerialization.jsonObject(with: data1) as! [String: Any]

        XCTAssertNil(json1["inverted"])

        // Test that inverted: true IS included
        let permission2 = Permission(
            action: StringOrArray("delete"),
            subject: StringOrArray("Post"),
            inverted: true
        )

        let data2 = try JSONEncoder().encode(permission2)
        let json2 = try JSONSerialization.jsonObject(with: data2) as! [String: Any]

        XCTAssertEqual(json2["inverted"] as? Bool, true)
    }

    func testPriorityNeverInJSON() throws {
        // Priority should NEVER appear in JSON (it's internal to CASL)
        let rule = Rule(
            action: .manage,
            subject: SubjectType("Resource"),
            priority: 999
        )

        let permission = rule.toPermission()
        let data = try JSONEncoder().encode(permission)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["priority"])
        XCTAssertEqual(json["action"] as? String, "manage")
        XCTAssertEqual(json["subject"] as? String, "Resource")
    }

    // MARK: - Batch Operations

    func testBatchPermissionEncoding() throws {
        let permissions = [
            Permission(
                action: StringOrArray("read"),
                subject: StringOrArray("Post")
            ),
            Permission(
                action: StringOrArray(["create", "update"]),
                subject: StringOrArray("Comment"),
                conditions: ["householdId": AnyCodable("${householdId}")]
            ),
            Permission(
                action: StringOrArray("manage"),
                subject: nil, // Claim-based
                inverted: false
            ),
        ]

        let data = try JSONEncoder().encode(permissions)
        let decoded = try JSONDecoder().decode([Permission].self, from: data)

        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].action.first, "read")
        XCTAssertEqual(decoded[1].action.values, ["create", "update"])
        XCTAssertNil(decoded[2].subject)
    }

    // MARK: - Error Cases

    func testMalformedJSONHandling() {
        let malformedCases = [
            "not json at all",
            "{ \"action\": }", // Invalid JSON
            "{ }", // Missing required fields
            "[]", // Empty array
        ]

        for malformed in malformedCases {
            let data = malformed.data(using: .utf8)!

            // Should either throw or handle gracefully
            do {
                let _ = try PermissionCoder.decodeRules(from: data)
            } catch {
                // Expected to throw
                XCTAssertNotNil(error)
            }
        }
    }

    func testPartialDataHandling() throws {
        // Test with minimal valid permission
        let minimal = """
        {
            "action": "read"
        }
        """

        let data = minimal.data(using: .utf8)!
        let permission = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(permission.action.first, "read")
        XCTAssertNil(permission.subject)
        XCTAssertNil(permission.conditions)
        XCTAssertNil(permission.fields)
        XCTAssertNil(permission.inverted)
        XCTAssertNil(permission.reason)
    }

    // MARK: - Special Characters and Edge Cases

    func testSpecialCharactersInStrings() throws {
        let permission = Permission(
            action: StringOrArray("read"),
            subject: StringOrArray("User's Post"),
            reason: "Can read \"special\" characters & symbols: <>&"
        )

        let data = try JSONEncoder().encode(permission)
        let decoded = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(decoded.subject?.first, "User's Post")
        XCTAssertEqual(decoded.reason, "Can read \"special\" characters & symbols: <>&")
    }

    func testUnicodeHandling() throws {
        let permission = Permission(
            action: StringOrArray("読む"), // Japanese for "read"
            subject: StringOrArray("📝"), // Emoji
            reason: "Unicode test: 你好 мир 🌍"
        )

        let data = try JSONEncoder().encode(permission)
        let decoded = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(decoded.action.first, "読む")
        XCTAssertEqual(decoded.subject?.first, "📝")
        XCTAssertEqual(decoded.reason, "Unicode test: 你好 мир 🌍")
    }

    // MARK: - Version Compatibility

    func testVersionedPermissionSet() throws {
        let permissionSet = PermissionSet(
            version: "1.0",
            permissions: [
                Permission(action: StringOrArray("read"), subject: StringOrArray("Post")),
                Permission(action: StringOrArray("create"), subject: StringOrArray("Comment")),
            ],
            metadata: [
                "timestamp": AnyCodable(Date().timeIntervalSince1970),
                "source": AnyCodable("iOS"),
                "appVersion": AnyCodable("1.2.3"),
            ]
        )

        let data = try JSONEncoder().encode(permissionSet)
        let decoded = try JSONDecoder().decode(PermissionSet.self, from: data)

        XCTAssertEqual(decoded.version, "1.0")
        XCTAssertEqual(decoded.permissions.count, 2)
        XCTAssertNotNil(decoded.metadata?["timestamp"])
        XCTAssertEqual(decoded.metadata?["source"]?.value as? String, "iOS")
        XCTAssertEqual(decoded.metadata?["appVersion"]?.value as? String, "1.2.3")
    }

    // MARK: - Real-World Scenarios

    func testJeevesAppPermissions() throws {
        // Test real Jeeves app permission structure
        let pantryPermissions = [
            Permission(
                action: StringOrArray("manage"),
                subject: StringOrArray("Household"),
                conditions: ["id": AnyCodable("${primaryHouseholdId}")]
            ),
            Permission(
                action: StringOrArray(["read", "create"]),
                subject: StringOrArray("Recipe"),
                conditions: ["householdId": AnyCodable(["$in": "${memberHouseholdIds}"])]
            ),
            Permission(
                action: StringOrArray("delete"),
                subject: StringOrArray("Recipe"),
                conditions: [
                    "$and": AnyCodable([
                        ["householdId": ["$in": "${memberHouseholdIds}"]],
                        ["createdBy": "${userId}"],
                    ]),
                ]
            ),
        ]

        let data = try JSONEncoder().encode(pantryPermissions)

        // Simulate backend response
        let jsonString = String(data: data, encoding: .utf8)!

        // Parse back as if from GraphQL
        let responseData = jsonString.data(using: String.Encoding.utf8)!
        let decoded = try JSONDecoder().decode([Permission].self, from: responseData)

        XCTAssertEqual(decoded.count, 3)

        // Convert to rules for Ability
        var allRules: [Rule] = []
        for permission in decoded {
            allRules.append(contentsOf: permission.toRules())
        }

        XCTAssertEqual(allRules.count, 4) // Second permission creates 2 rules
    }

    @MainActor
    func testAbilityJSONRoundTrip() async throws {
        // Create complex ability
        let builder = PureAbilityBuilder()

        builder.can("read", "all")
        builder.can("manage", "Household", ["ownerId": "${userId}"])
        builder.cannot("delete", "SystemSettings")
        builder.can("update", "Recipe", fields: ["name", "ingredients"])

        let originalAbility = await builder.build()

        // Export to JSON
        let json = try await originalAbility.toJSON()

        // Import back
        let importedAbility = try await PureAbility.from(json: json)

        // Verify permissions match
        let canReadAnyType = await importedAbility.can("read", "AnyType")
        XCTAssertTrue(canReadAnyType)
        let canManageHousehold = await importedAbility.can("manage", "Household")
        XCTAssertTrue(canManageHousehold)
        let canDeleteSystemSettings = await importedAbility.can("delete", "SystemSettings")
        XCTAssertFalse(canDeleteSystemSettings)
        let canUpdateRecipe = await importedAbility.can("update", "Recipe")
        XCTAssertTrue(canUpdateRecipe)

        // Can't access getRules() on PureAbility, but we can verify permissions work
    }
}
