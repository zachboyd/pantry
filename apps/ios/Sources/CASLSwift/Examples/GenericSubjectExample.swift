import Foundation

// MARK: - Example showing Generic Subject Usage

// MARK: Traditional Approach (Original)

/// Traditional household subject with boilerplate
struct TraditionalHousehold: Subject, IdentifiableSubject, Sendable {
    static let subjectType: SubjectType = "Household"

    let id: String
    let name: String
    let ownerId: String
    let memberCount: Int

    var subjectType: SubjectType { Self.subjectType }
}

/// Traditional user subject with boilerplate
struct TraditionalUser: Subject, IdentifiableSubject, Sendable {
    static let subjectType: SubjectType = "User"

    let id: String
    let email: String
    let name: String

    var subjectType: SubjectType { Self.subjectType }
}

// MARK: Generic Approach (New)

/// Household properties without Subject boilerplate
struct HouseholdProperties: Sendable {
    let name: String
    let ownerId: String
    let memberCount: Int
}

/// User properties without Subject boilerplate
struct UserProperties: Sendable {
    let email: String
    let name: String
}

// Create subjects using the generic approach
typealias GenericHousehold = StringIdentifiableSubject<HouseholdProperties>
typealias GenericUser = StringIdentifiableSubject<UserProperties>

// MARK: - Usage Examples

func demonstrateGenericSubjects() {
    // Traditional approach - lots of boilerplate
    let traditionalHousehold = TraditionalHousehold(
        id: "house-1",
        name: "Smith Family",
        ownerId: "user-1",
        memberCount: 4
    )

    let traditionalUser = TraditionalUser(
        id: "user-1",
        email: "john@example.com",
        name: "John Smith"
    )

    // Generic approach - less boilerplate
    let genericHousehold = GenericHousehold(
        id: "house-1",
        properties: HouseholdProperties(
            name: "Smith Family",
            ownerId: "user-1",
            memberCount: 4
        ),
        subjectType: "Household"
    )

    let genericUser = GenericUser(
        id: "user-1",
        properties: UserProperties(
            email: "john@example.com",
            name: "John Smith"
        ),
        subjectType: "User"
    )

    // Using the factory methods
    let factoryHousehold = SubjectFactory.identifiable(
        id: "house-1",
        properties: HouseholdProperties(
            name: "Smith Family",
            ownerId: "user-1",
            memberCount: 4
        ),
        type: "Household"
    )

    // Using the builder pattern
    let builderHousehold = SubjectFactory.build(
        id: "house-1",
        properties: HouseholdProperties(
            name: "Smith Family",
            ownerId: "user-1",
            memberCount: 4
        )
    )
    .withType("Household")
    .build()

    // Simple subjects for basic use cases
    let simpleSubject = SubjectFactory.simple(
        type: "Article",
        id: "article-1",
        properties: [
            "title": "Introduction to CASL",
            "authorId": "user-1",
            "published": true,
        ]
    )

    // Using convenience functions
    let quickSubject = makeIdentifiableSubject(
        id: "item-1",
        properties: ["name": "Quick Item"],
        type: "Item"
    )
}

// MARK: - Advanced Examples

/// Example of a custom subject that extends generic functionality
struct AdvancedBlogPost: Subject, IdentifiableSubject, Sendable {
    // Use composition with generic subject
    private let generic: StringIdentifiableSubject<BlogPostProperties>

    struct BlogPostProperties: Sendable {
        let title: String
        let content: String
        let authorId: String
        let tags: [String]
        let publishedAt: Date?
    }

    static let subjectType: SubjectType = "BlogPost"

    var id: String { generic.id }
    var subjectType: SubjectType { Self.subjectType }

    // Expose properties with computed properties for convenience
    var title: String { generic.properties.title }
    var content: String { generic.properties.content }
    var authorId: String { generic.properties.authorId }
    var tags: [String] { generic.properties.tags }
    var isPublished: Bool { generic.properties.publishedAt != nil }

    init(id: String, title: String, content: String, authorId: String, tags: [String] = [], publishedAt: Date? = nil) {
        generic = StringIdentifiableSubject(
            id: id,
            properties: BlogPostProperties(
                title: title,
                content: content,
                authorId: authorId,
                tags: tags,
                publishedAt: publishedAt
            ),
            subjectType: Self.subjectType
        )
    }
}

// MARK: - Migration Guide Example

/// Shows how to migrate from traditional to generic approach
enum MigrationExample {
    // Step 1: Original implementation
    struct OldProduct: Subject, IdentifiableSubject, Sendable {
        static let subjectType: SubjectType = "Product"
        let id: String
        let name: String
        let price: Double
        let inStock: Bool
        var subjectType: SubjectType { Self.subjectType }
    }

    // Step 2: Extract properties
    struct ProductProperties: Sendable {
        let name: String
        let price: Double
        let inStock: Bool
    }

    // Step 3: Create type alias
    typealias NewProduct = StringIdentifiableSubject<ProductProperties>

    // Step 4: Use in code (backward compatible)
    static func createProducts() {
        // Old way
        let oldProduct = OldProduct(
            id: "prod-1",
            name: "Widget",
            price: 19.99,
            inStock: true
        )

        // New way - same functionality, less code
        let newProduct = NewProduct(
            id: "prod-1",
            properties: ProductProperties(
                name: "Widget",
                price: 19.99,
                inStock: true
            ),
            subjectType: "Product"
        )

        // Both can be used with CASL abilities in the same way
        print("Old subject type: \(oldProduct.subjectType)")
        print("New subject type: \(newProduct.subjectType)")
    }
}

// MARK: - Performance Comparison

/// Example showing that generic subjects have the same performance characteristics
func performanceComparison() {
    // Traditional subjects compile to the same efficient code
    let traditional = TraditionalUser(
        id: "user-1",
        email: "test@example.com",
        name: "Test User"
    )

    // Generic subjects have zero overhead
    let generic = GenericUser(
        id: "user-1",
        properties: UserProperties(
            email: "test@example.com",
            name: "Test User"
        ),
        subjectType: "User"
    )

    // Both work identically with abilities
    let ability = AbilityBuilder<String, AnySubject>()
        .can("read", "User")
        .build()

    let canReadTraditional = ability.can("read", traditional)
    let canReadGeneric = ability.can("read", generic)

    assert(canReadTraditional == canReadGeneric)
}
