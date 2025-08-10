@testable import CASLSwift
import XCTest

final class SerializationTests: XCTestCase {
    // MARK: - Permission Encoding Tests

    func testPermissionEncoding() throws {
        let permission = Permission(
            action: StringOrArray("update"),
            subject: StringOrArray("Household"),
            conditions: ["ownerId": AnyCodable("${userId}")],
            inverted: false,
            fields: StringOrArray(["name", "description"]),
            reason: "Users can update their own households"
        )

        let data = try JSONEncoder().encode(permission)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["action"] as? String, "update")
        XCTAssertEqual(json["subject"] as? String, "Household")
        XCTAssertNil(json["inverted"]) // Should not encode false
        XCTAssertEqual(json["fields"] as? [String], ["name", "description"])
        XCTAssertEqual(json["reason"] as? String, "Users can update their own households")
        XCTAssertNil(json["priority"]) // Priority should NOT be in JSON

        let conditions = json["conditions"] as? [String: Any]
        XCTAssertEqual(conditions?["ownerId"] as? String, "${userId}")
    }

    func testPermissionDecoding() throws {
        let json = """
        {
            "action": "delete",
            "subject": "Recipe",
            "conditions": {
                "householdId": "${householdId}",
                "createdBy": "${userId}"
            },
            "inverted": true,
            "fields": ["id"],
            "reason": "Cannot delete others' recipes"
        }
        """

        let data = json.data(using: .utf8)!
        let permission = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(permission.action.first, "delete")
        XCTAssertEqual(permission.subject?.first, "Recipe")
        XCTAssertEqual(permission.inverted, true)
        XCTAssertEqual(permission.fields?.values, ["id"])
        XCTAssertEqual(permission.reason, "Cannot delete others' recipes")

        let conditions = permission.conditions
        XCTAssertEqual(conditions?["householdId"]?.value as? String, "${householdId}")
        XCTAssertEqual(conditions?["createdBy"]?.value as? String, "${userId}")
    }

    func testPermissionWithArrayActions() throws {
        let json = """
        {
            "action": ["read", "update"],
            "subject": "Post",
            "conditions": {
                "authorId": "${userId}"
            }
        }
        """

        let data = json.data(using: .utf8)!
        let permission = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(permission.action.values, ["read", "update"])
        XCTAssertEqual(permission.subject?.first, "Post")

        // Test conversion to multiple rules
        let rules = permission.toRules()
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].action.value, "read")
        XCTAssertEqual(rules[1].action.value, "update")
    }

    func testClaimBasedRule() throws {
        // CASL supports rules without subjects (claim-based)
        let json = """
        {
            "action": "manage",
            "inverted": false
        }
        """

        let data = json.data(using: .utf8)!
        let permission = try JSONDecoder().decode(Permission.self, from: data)

        XCTAssertEqual(permission.action.first, "manage")
        XCTAssertNil(permission.subject)
        XCTAssertEqual(permission.inverted, false)

        // When converting to Rule, it should default to "all" subject
        let rule = permission.toRule()
        XCTAssertEqual(rule.subject.value, "all")
    }

    // MARK: - Rule Conversion Tests

    func testRuleToPermissionConversion() {
        let rule = Rule(
            action: Action("manage"),
            subject: SubjectType("Household"),
            conditions: Conditions(["ownerId": "${userId}"]),
            inverted: false,
            fields: ["name"],
            reason: "Owner can manage",
            priority: 100 // Note: priority won't be in the Permission
        )

        let permission = rule.toPermission()

        XCTAssertEqual(permission.action.first, "manage")
        XCTAssertEqual(permission.subject?.first, "Household")
        XCTAssertNil(permission.inverted) // false is not encoded
        XCTAssertEqual(permission.fields?.values, ["name"])
        XCTAssertEqual(permission.reason, "Owner can manage")
        // Priority should NOT be in the permission
    }

    func testPermissionToRuleConversion() {
        let permission = Permission(
            action: StringOrArray("read"),
            subject: nil, // Claim-based rule
            conditions: nil,
            inverted: false,
            fields: nil,
            reason: nil
        )

        let rule = permission.toRule()

        XCTAssertEqual(rule.action.value, "read")
        XCTAssertEqual(rule.subject.value, "all") // Defaults to "all" for claim-based
        XCTAssertNil(rule.conditions)
        XCTAssertFalse(rule.inverted)
        XCTAssertNil(rule.fields)
        XCTAssertNil(rule.reason)
        XCTAssertEqual(rule.priority, 0)
    }

    // MARK: - PermissionCoder Tests

    func testEncodeDecodeRules() throws {
        let rules = [
            Rule(
                action: .read,
                subject: SubjectType("Household")
            ),
            Rule(
                action: .manage,
                subject: SubjectType("Recipe"),
                conditions: Conditions(["householdId": "${householdId}"]),
                inverted: false,
                fields: ["title", "ingredients"],
                priority: 10 // Internal priority, won't be in JSON
            ),
            Rule(
                action: .delete,
                subject: SubjectType.all,
                inverted: true
            ),
        ]

        // Encode
        let data = try PermissionCoder.encode(rules: rules)

        // Decode
        let decodedRules = try PermissionCoder.decodeRules(from: data)

        XCTAssertEqual(decodedRules.count, 3)

        XCTAssertEqual(decodedRules[0].action.value, "read")
        XCTAssertEqual(decodedRules[0].subject.value, "Household")

        XCTAssertEqual(decodedRules[1].action.value, "manage")
        XCTAssertEqual(decodedRules[1].subject.value, "Recipe")
        XCTAssertEqual(decodedRules[1].fields, ["title", "ingredients"])
        XCTAssertEqual(decodedRules[1].priority, 0) // Priority is not preserved in JSON, defaults to 0

        XCTAssertEqual(decodedRules[2].action.value, "delete")
        XCTAssertEqual(decodedRules[2].subject.value, "all")
        XCTAssertTrue(decodedRules[2].inverted)
    }

    func testPermissionSetEncoding() throws {
        let rules = [
            Rule(action: .read, subject: SubjectType("Household")),
            Rule(action: .create, subject: SubjectType("Recipe")),
        ]

        let metadata: [String: Any] = [
            "userId": "user123",
            "timestamp": "2024-01-20T10:00:00Z",
            "source": "api",
        ]

        let data = try PermissionCoder.encode(
            rules: rules,
            version: "1.0",
            metadata: metadata
        )

        let permissionSet = try PermissionCoder.decodePermissionSet(from: data)

        XCTAssertEqual(permissionSet.version, "1.0")
        XCTAssertEqual(permissionSet.permissions.count, 2)
        XCTAssertEqual(permissionSet.metadata?["userId"]?.value as? String, "user123")
        XCTAssertEqual(permissionSet.metadata?["source"]?.value as? String, "api")
    }

    // MARK: - Error Handling Tests

    func testInvalidJSONError() {
        let invalidJSON = "{ invalid json"

        XCTAssertThrowsError(try PermissionCoder.decodeRules(from: invalidJSON)) { error in
            guard case PermissionError.decodingFailed = error else {
                XCTFail("Expected decodingFailed error")
                return
            }
        }
    }

    func testUnsupportedVersionError() throws {
        let json = """
        {
            "version": "99.0",
            "permissions": []
        }
        """

        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try PermissionCoder.decodePermissionSet(from: data)) { error in
            guard case let PermissionError.unsupportedVersion(version) = error else {
                XCTFail("Expected unsupportedVersion error")
                return
            }
            XCTAssertEqual(version, "99.0")
        }
    }

    // MARK: - AbilityBuilder JSON Tests

    @MainActor
    func testAbilityBuilderFromJSON() async throws {
        let json = """
        [
            {
                "action": "read",
                "subject": "Household"
            },
            {
                "action": "manage",
                "subject": "Recipe",
                "conditions": {
                    "ownerId": "${userId}"
                }
            }
        ]
        """

        let builder = PureAbilityBuilder()
        try builder.from(jsonString: json)

        let rules = builder.getRules()
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].action.value, "read")
        XCTAssertEqual(rules[1].action.value, "manage")
    }

    // MARK: - Ability Import/Export Tests

    func testAbilityExportImport() async throws {
        // Create ability with rules
        let originalRules = [
            Rule(action: .read, subject: SubjectType("Household")),
            Rule(action: .create, subject: SubjectType("Recipe")),
            Rule(action: .delete, subject: SubjectType("Recipe"), inverted: true),
        ]

        let ability1 = await PureAbility.create(rules: originalRules)

        // Export to JSON
        let json = try await ability1.toJSON()

        // Import to new ability
        let ability2 = try await PureAbility.from(json: json)

        // Verify permissions match
        let canRead = await ability2.can("read", "Household")
        XCTAssertTrue(canRead)
        let canCreate = await ability2.can("create", "Recipe")
        XCTAssertTrue(canCreate)
        let cannotDelete = await ability2.cannot("delete", "Recipe")
        XCTAssertTrue(cannotDelete)
    }
}
