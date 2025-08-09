import Foundation

// MARK: - Example of using CASL conditions system

/// Example subject with various properties
struct BlogPost: Subject, IdentifiableSubject, Sendable {
    static let subjectType: SubjectType = "BlogPost"
    
    let id: String
    let title: String
    let content: String
    let authorId: String
    let published: Bool
    let likes: Int
    let tags: [String]
    let createdAt: Date
    
    var subjectType: SubjectType { Self.subjectType }
}

/// Example of building complex conditions
func conditionsExamples() {
    
    // Example 1: Simple field equality
    let authorCondition = Conditions(["authorId": "user123"])
    
    // Example 2: Using operators
    let popularPostCondition = Conditions([
        "likes": [ConditionOperator.gte.rawValue: 100]
    ])
    
    // Example 3: Multiple conditions (implicit AND)
    let publishedPopularCondition = Conditions([
        "published": true,
        "likes": [ConditionOperator.gt.rawValue: 50]
    ])
    
    // Example 4: Using the builder syntax
    let complexCondition = conditions {
        Conditions.field("published", eq: true)
        Conditions.field("likes", gte: 100)
        Conditions.field("tags", in: ["swift", "ios", "casl"])
    }
    
    // Example 5: Logical operators
    let orCondition = Conditions.or([
        Conditions.field("authorId", eq: "user123"),
        Conditions.field("likes", gt: 1000)
    ])
    
    // Example 6: Nested conditions
    let nestedCondition = conditions {
        Conditions.field("published", eq: true)
        Conditions.or([
            Conditions.field("authorId", eq: "user123"),
            Conditions.and([
                Conditions.field("likes", gte: 500),
                Conditions.field("tags", in: ["featured", "trending"])
            ])
        ])
    }
    
    // Example 7: Negation
    let notCondition = Conditions.not(
        Conditions.field("status", eq: "draft")
    )
    
    // Example 8: Regex matching
    let regexCondition = Conditions.field("title", regex: "^Swift.*Tutorial$")
    
    // Example 9: Field existence
    let hasVideoCondition = Conditions.field("videoUrl", exists: true)
}

/// Example of using conditions with abilities
@MainActor
func abilityWithConditionsExample() async {
    let builder = PureAbilityBuilder()
    
    // Users can read any published blog post
    builder.can("read", "BlogPost", ["published": true])
    
    // Users can update their own blog posts
    builder.can("update", "BlogPost", ["authorId": "${user.id}"])  // Note: variable substitution would be handled by backend
    
    // Users can delete their own unpublished posts
    builder.can("delete", "BlogPost", [
        "authorId": "${user.id}",
        "published": false
    ])
    
    // Admins can manage posts with more than 100 reports
    builder.can("manage", "BlogPost", [
        "reports": [ConditionOperator.gt.rawValue: 100]
    ])
    
    // Complex condition using builder
    let complexConditions = conditions {
        Conditions.field("published", eq: true)
        Conditions.or([
            Conditions.field("authorId", eq: "currentUserId"),
            Conditions.field("likes", gte: 1000)
        ])
    }.data
    
    builder.can("feature", "BlogPost", complexConditions)
    
    let ability = await builder.build()
    
    // Test the ability
    let post = BlogPost(
        id: "post1",
        title: "Swift CASL Tutorial",
        content: "Learn how to use CASL in Swift...",
        authorId: "currentUserId",
        published: true,
        likes: 150,
        tags: ["swift", "casl", "tutorial"],
        createdAt: Date()
    )
    
    let canRead = await ability.can("read", post)  // true (published)
    let canUpdate = await ability.can("update", post)  // depends on authorId match
    let canDelete = await ability.can("delete", post)  // false (published)
    
    print("Can read: \(canRead)")
    print("Can update: \(canUpdate)")
    print("Can delete: \(canDelete)")
}

/// Example of field-level permissions
@MainActor
func fieldPermissionsExample() async {
    let builder = PureAbilityBuilder()
    
    // Users can read only specific fields of unpublished posts
    builder.can("read", "BlogPost", fields: ["title", "tags"], [
        "published": false
    ])
    
    // Users can read all fields of published posts
    builder.can("read", "BlogPost", ["published": true])
    
    // Authors can update specific fields of their own posts
    builder.can("update", "BlogPost", fields: ["title", "content", "tags"], [
        "authorId": "currentUserId"
    ])
    
    let ability = await builder.build()
    
    let unpublishedPost = BlogPost(
        id: "post2",
        title: "Draft Post",
        content: "Secret content...",
        authorId: "otherUser",
        published: false,
        likes: 0,
        tags: ["draft"],
        createdAt: Date()
    )
    
    // Check field permissions
    let readFields = await ability.permittedFieldsBy("read", unpublishedPost)
    print("Can read fields: \(readFields ?? [])") // ["title", "tags"]
    
    // Filter object to permitted fields
    if let ability = ability as? Ability<StringAction, StringSubject> {
        let filteredData = await ability.filterPermittedFields(
            unpublishedPost,
            for: .init(rawValue: "read")!,
            on: unpublishedPost
        )
        print("Filtered data: \(filteredData)")
    }
}

/// Example of custom condition matchers
func customMatcherExample() {
    // Create a custom matcher for special business logic
    let customMatchers: [String: @Sendable (Any?, Any) -> Bool] = [
        "isRecentlyPublished": { fieldValue, expectedValue in
            guard let date = fieldValue as? Date,
                  let daysAgo = expectedValue as? Int else { return false }
            
            let daysSincePublished = Calendar.current.dateComponents(
                [.day],
                from: date,
                to: Date()
            ).day ?? 0
            
            return daysSincePublished <= daysAgo
        },
        "hasMinimumEngagement": { fieldValue, expectedValue in
            guard let post = fieldValue as? BlogPost,
                  let threshold = expectedValue as? Int else { return false }
            
            // Custom engagement calculation
            let engagement = post.likes + (post.tags.count * 10)
            return engagement >= threshold
        }
    ]
    
    let customMatcher = CustomConditionsMatcher(customMatchers: customMatchers)
    let evaluator = BasicConditionEvaluator(matcher: customMatcher)
    
    // Use with ability
    let ability = PureAbility(
        ruleEngine: RuleEngine(),
        conditionEvaluator: evaluator
    )
}