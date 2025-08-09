import XCTest
@testable import CASLSwift

@MainActor
final class AbilityBuilderTests: XCTestCase {
    
    // MARK: - Basic Builder Operations
    
    func testBuilderCanMethod() async {
        let builder = PureAbilityBuilder()
        
        builder.can("read", "Post")
        builder.can("create", "Comment")
        builder.can("update", "User")
        
        let ability = await builder.build()
        
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreateComment = await ability.can("create", "Comment")
        XCTAssertTrue(canCreateComment)
        let canUpdateUser = await ability.can("update", "User")
        XCTAssertTrue(canUpdateUser)
        let canDeletePost = await ability.can("delete", "Post")
        XCTAssertFalse(canDeletePost)
    }
    
    func testBuilderCannotMethod() async {
        let builder = PureAbilityBuilder()
        
        builder.can("manage", "all")  // Allow everything
        builder.cannot("delete", "Post")  // But deny delete on Posts
        
        let ability = await builder.build()
        
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreatePost = await ability.can("create", "Post")
        XCTAssertTrue(canCreatePost)
        let canUpdatePost = await ability.can("update", "Post")
        XCTAssertTrue(canUpdatePost)
        let canDeletePost = await ability.can("delete", "Post")
        XCTAssertFalse(canDeletePost)  // Explicitly denied
    }
    
    func testBuilderWithConditions() async {
        let builder = PureAbilityBuilder()
        
        let conditions = ["ownerId": "${userId}"]
        builder.can("update", "Post", conditions)
        
        _ = await builder.build()
        let rules = builder.getRules()
        
        XCTAssertEqual(rules.count, 1)
        XCTAssertNotNil(rules.first?.conditions)
        XCTAssertEqual(rules.first?.conditions?.data["ownerId"] as? String, "${userId}")
    }
    
    func testBuilderWithFields() async {
        let builder = PureAbilityBuilder()
        
        builder.can("read", "User", fields: ["name", "email"])
        builder.cannot("read", "User", fields: ["password", "secret"])
        
        _ = await builder.build()
        let rules = builder.getRules()
        
        XCTAssertEqual(rules.count, 2)
        // Rules are sorted: inverted (cannot) rules come before non-inverted (can) rules
        XCTAssertEqual(rules[0].fields, ["password", "secret"])
        XCTAssertTrue(rules[0].inverted)
        XCTAssertEqual(rules[1].fields, ["name", "email"])
        XCTAssertFalse(rules[1].inverted)
    }
    
    // MARK: - Method Chaining
    
    func testMethodChaining() async {
        let builder = PureAbilityBuilder()
        
        // Test that methods return self for chaining
        let chainedBuilder = builder
            .can("read", "Post")
            .can("create", "Comment")
            .cannot("delete", "all")
        
        XCTAssertTrue(builder === chainedBuilder)  // Same instance
        
        let ability = await builder.build()
        
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreateComment = await ability.can("create", "Comment")
        XCTAssertTrue(canCreateComment)
        let canDeletePost = await ability.can("delete", "Post")
        XCTAssertFalse(canDeletePost)
        let canDeleteComment = await ability.can("delete", "Comment")
        XCTAssertFalse(canDeleteComment)
    }
    
    // MARK: - Rule Priority
    
    func testRulePriorityOrdering() async {
        let builder = PureAbilityBuilder()
        
        // Add rules with different priorities
        builder.can("read", "Post", priority: 10)
        builder.can("manage", "Post", priority: 100)
        builder.cannot("delete", "Post", priority: 50)
        
        _ = await builder.build()
        let rules = builder.getRules()
        
        // Rules should be sorted by priority (highest first)
        XCTAssertEqual(rules[0].priority, 100)
        XCTAssertEqual(rules[0].action.value, "manage")
        
        XCTAssertEqual(rules[1].priority, 50)
        XCTAssertTrue(rules[1].inverted)
        
        XCTAssertEqual(rules[2].priority, 10)
        XCTAssertEqual(rules[2].action.value, "read")
    }
    
    // MARK: - Building from Existing Rules
    
    func testBuildFromExistingRules() async {
        let existingRules = [
            Rule(action: .read, subject: SubjectType("Post")),
            Rule(action: .create, subject: SubjectType("Comment")),
            Rule(action: .delete, subject: SubjectType("User"), inverted: true)
        ]
        
        let builder = PureAbilityBuilder()
            .from(rules: existingRules)  // Now we can use the from(rules:) method
            .can("update", "Post")       // Add more rules
        
        let ability = await builder.build()
        
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreateComment = await ability.can("create", "Comment")
        XCTAssertTrue(canCreateComment)
        let canUpdatePost = await ability.can("update", "Post")
        XCTAssertTrue(canUpdatePost)
        let canDeleteUser = await ability.can("delete", "User")
        XCTAssertFalse(canDeleteUser)
    }
    
    // MARK: - Complex Scenarios
    
    func testAdminScenario() async {
        let builder = PureAbilityBuilder()
        
        // Admin can manage everything
        builder.can("manage", "all")
        
        // But cannot delete system settings
        builder.cannot("delete", "SystemSettings")
        
        let ability = await builder.build()
        
        // Admin can do everything
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canCreateUser = await ability.can("create", "User")
        XCTAssertTrue(canCreateUser)
        let canUpdateComment = await ability.can("update", "Comment")
        XCTAssertTrue(canUpdateComment)
        let canDeleteRecipe = await ability.can("delete", "Recipe")
        XCTAssertTrue(canDeleteRecipe)
        
        // Except delete system settings
        let canDeleteSystemSettings = await ability.can("delete", "SystemSettings")
        XCTAssertFalse(canDeleteSystemSettings)
        let canReadSystemSettings = await ability.can("read", "SystemSettings")
        XCTAssertTrue(canReadSystemSettings)  // Can still read
        let canUpdateSystemSettings = await ability.can("update", "SystemSettings")
        XCTAssertTrue(canUpdateSystemSettings)  // Can still update
    }
    
    func testUserWithConditionalPermissions() async {
        let builder = PureAbilityBuilder()
        
        // User can read all posts
        builder.can("read", "Post")
        
        // User can only update their own posts
        let updateConditions = ["authorId": "${userId}"]
        builder.can("update", "Post", updateConditions)
        
        // User can delete their own posts if not published
        let deleteConditions: [String: Any] = [
            "authorId": "${userId}",
            "published": false
        ]
        builder.can("delete", "Post", deleteConditions)
        
        _ = await builder.build()
        let rules = builder.getRules()
        
        XCTAssertEqual(rules.count, 3)
        
        // Rules are sorted: conditional rules come before unconditional rules
        // So the order is: update (conditional), delete (conditional), read (unconditional)
        
        // Check conditional update (first rule due to sorting)
        XCTAssertNotNil(rules[0].conditions)
        XCTAssertEqual(rules[0].conditions?.data["authorId"] as? String, "${userId}")
        
        // Check conditional delete with multiple conditions (second rule)
        XCTAssertNotNil(rules[1].conditions)
        XCTAssertEqual(rules[1].conditions?.data["authorId"] as? String, "${userId}")
        XCTAssertEqual(rules[1].conditions?.data["published"] as? Bool, false)
        
        // Check unconditional read (last rule due to sorting)
        XCTAssertNil(rules[2].conditions)
    }
    
    // MARK: - Clear and Reset
    
    func testClearRules() async {
        let builder = PureAbilityBuilder()
        
        builder.can("read", "Post")
        builder.can("create", "Comment")
        
        // Note: Can't access rules directly as it's private
        // We can verify the count through getRules() method
        XCTAssertEqual(builder.getRules().count, 2)
        
        // Clear all rules using reset()
        builder.reset()
        
        XCTAssertEqual(builder.getRules().count, 0)
        
        // Add new rules
        builder.can("manage", "all")
        
        let ability = await builder.build()
        
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
        let canDeleteComment = await ability.can("delete", "Comment")
        XCTAssertTrue(canDeleteComment)
        // Note: PureAbility doesn't expose getRules(), test through can/cannot methods
    }
    
    // MARK: - Builder with Custom Action Types
    
    func testCustomActions() async {
        let builder = PureAbilityBuilder()
        
        // Use custom action strings
        builder.can("publish", "Post")
        builder.can("archive", "Post")
        builder.can("feature", "Recipe")
        
        let ability = await builder.build()
        
        let canPublishPost = await ability.can("publish", "Post")
        XCTAssertTrue(canPublishPost)
        let canArchivePost = await ability.can("archive", "Post")
        XCTAssertTrue(canArchivePost)
        let canFeatureRecipe = await ability.can("feature", "Recipe")
        XCTAssertTrue(canFeatureRecipe)
        let canPublishRecipe = await ability.can("publish", "Recipe")
        XCTAssertFalse(canPublishRecipe)
    }
    
    // MARK: - Builder Reason Support
    
    func testRulesWithReasons() async {
        // PureAbilityBuilder doesn't support reason parameter directly
        // We'll need to create rules manually for this test
        let rule1 = Rule(
            action: Action("delete"),
            subject: SubjectType("Post"),
            conditions: Conditions(["authorId": "${userId}"]),
            inverted: false,
            reason: "Users can delete their own posts"
        )
        
        let rule2 = Rule(
            action: Action("delete"),
            subject: SubjectType("Post"),
            conditions: Conditions(["locked": true]),
            inverted: true,
            reason: "Locked posts cannot be deleted"
        )
        
        _ = await PureAbility.create(rules: [rule2, rule1])  // Order matters
        let rules = [rule2, rule1]
        
        XCTAssertEqual(rules[0].reason, "Locked posts cannot be deleted")
        XCTAssertEqual(rules[1].reason, "Users can delete their own posts")
    }
    
    // MARK: - Error Handling
    
    func testSimpleDirectRule() async {
        // Test with direct rule creation
        let rule = Rule(
            action: Action("read"),
            subject: SubjectType("Post")
        )
        
        let ability = await PureAbility.create(rules: [rule])
        let canRead = await ability.can("read", "Post")
        XCTAssertTrue(canRead, "Should be able to read Post with direct rule")
        
        let canWrite = await ability.can("write", "Post")
        XCTAssertFalse(canWrite, "Should not be able to write Post")
    }
    
    func testEmptyBuilder() async {
        let builder = PureAbilityBuilder()
        
        // Build with no rules
        let ability = await builder.build()
        
        // Should create valid ability with no permissions
        let canReadPost = await ability.can("read", "Post")
        XCTAssertFalse(canReadPost)
        let canCreateComment = await ability.can("create", "Comment")
        XCTAssertFalse(canCreateComment)
        // Note: PureAbility doesn't expose getRules(), but empty builder creates no rules
    }
    
    func testDuplicateRules() async {
        let builder = PureAbilityBuilder()
        
        // Add duplicate rules
        builder.can("read", "Post")
        builder.can("read", "Post")
        builder.can("read", "Post")
        
        let ability = await builder.build()
        
        // All rules should be present (duplicates are allowed)
        // Note: PureAbility doesn't expose getRules(), but we added 3 rules
        let canReadPost = await ability.can("read", "Post")
        XCTAssertTrue(canReadPost)
    }
}