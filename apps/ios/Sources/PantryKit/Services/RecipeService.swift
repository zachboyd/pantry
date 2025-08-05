import Foundation

// MARK: - Recipe Service Implementation

/// Service for managing recipes - mock implementation for MVP
@MainActor
public final class RecipeService: RecipeServiceProtocol {
    private static let logger = Logger.recipe

    private var recipesStorage: [Recipe] = []

    public init() {
        Self.logger.info("🍳 RecipeService initialized")
        seedMockData()
    }

    // MARK: - Public Methods

    public func getRecipes() async throws -> [Recipe] {
        Self.logger.info("📡 Getting all recipes")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds

        Self.logger.info("✅ Retrieved \(recipesStorage.count) recipes")
        return recipesStorage
    }

    public func searchRecipes(query: String) async throws -> [Recipe] {
        Self.logger.info("🔍 Searching recipes for: \(query)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let searchQuery = query.lowercased()
        let filteredRecipes = recipesStorage.filter { recipe in
            recipe.name.lowercased().contains(searchQuery) ||
                recipe.description?.lowercased().contains(searchQuery) == true ||
                recipe.tags.contains { $0.lowercased().contains(searchQuery) } ||
                recipe.ingredients.contains { $0.name.lowercased().contains(searchQuery) }
        }

        Self.logger.info("✅ Found \(filteredRecipes.count) recipes matching '\(query)'")
        return filteredRecipes
    }

    public func getRecipe(id: String) async throws -> Recipe? {
        Self.logger.info("📡 Getting recipe with ID: \(id)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let recipe = recipesStorage.first { $0.id == id }

        if recipe != nil {
            Self.logger.info("✅ Found recipe with ID: \(id)")
        } else {
            Self.logger.warning("⚠️ Recipe not found with ID: \(id)")
        }

        return recipe
    }

    // MARK: - Additional Methods

    public func getRecipesByDifficulty(_ difficulty: RecipeDifficulty) async throws -> [Recipe] {
        Self.logger.info("📡 Getting recipes with difficulty: \(difficulty.rawValue)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let filteredRecipes = recipesStorage.filter { $0.difficulty == difficulty }
        Self.logger.info("✅ Found \(filteredRecipes.count) \(difficulty.rawValue) recipes")
        return filteredRecipes
    }

    public func getRecipesByTag(_ tag: String) async throws -> [Recipe] {
        Self.logger.info("📡 Getting recipes with tag: \(tag)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let filteredRecipes = recipesStorage.filter { $0.tags.contains(tag.lowercased()) }
        Self.logger.info("✅ Found \(filteredRecipes.count) recipes with tag '\(tag)'")
        return filteredRecipes
    }

    public func getQuickRecipes(maxPrepTime: Int) async throws -> [Recipe] {
        Self.logger.info("📡 Getting quick recipes (max \(maxPrepTime) min prep)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let filteredRecipes = recipesStorage.filter { recipe in
            guard let prepTime = recipe.prepTime else { return false }
            return prepTime <= maxPrepTime
        }

        Self.logger.info("✅ Found \(filteredRecipes.count) quick recipes")
        return filteredRecipes
    }

    // MARK: - Private Methods

    private func seedMockData() {
        let recipes = [
            Recipe(
                id: UUID().uuidString,
                name: "Chicken Stir Fry",
                description: "Quick and healthy chicken stir fry with fresh vegetables",
                ingredients: [
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Chicken Breast",
                        quantity: 1.0,
                        unit: "lb",
                        notes: "Cut into strips"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Bell Peppers",
                        quantity: 2.0,
                        unit: "pieces",
                        notes: "Mixed colors, sliced"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Soy Sauce",
                        quantity: 3.0,
                        unit: "tbsp",
                        notes: "Low sodium preferred"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Garlic",
                        quantity: 3.0,
                        unit: "cloves",
                        notes: "Minced"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Vegetable Oil",
                        quantity: 2.0,
                        unit: "tbsp",
                        notes: "For cooking"
                    ),
                ],
                instructions: [
                    "Heat oil in a large wok or skillet over medium-high heat",
                    "Add chicken strips and cook until golden brown, about 5-6 minutes",
                    "Add garlic and cook for 30 seconds until fragrant",
                    "Add bell peppers and stir-fry for 3-4 minutes until crisp-tender",
                    "Add soy sauce and toss to combine",
                    "Serve immediately over rice or noodles",
                ],
                prepTime: 15,
                cookTime: 10,
                servings: 4,
                difficulty: .easy,
                tags: ["quick", "healthy", "asian", "protein", "vegetables"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Banana Smoothie",
                description: "Creamy and nutritious banana smoothie perfect for breakfast",
                ingredients: [
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Bananas",
                        quantity: 2.0,
                        unit: "pieces",
                        notes: "Ripe, peeled"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Milk",
                        quantity: 1.0,
                        unit: "cup",
                        notes: "Any type"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Honey",
                        quantity: 1.0,
                        unit: "tbsp",
                        notes: "Optional, to taste"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Ice",
                        quantity: 0.5,
                        unit: "cup",
                        notes: "For thickness"
                    ),
                ],
                instructions: [
                    "Add bananas, milk, honey, and ice to a blender",
                    "Blend on high speed for 60-90 seconds until smooth",
                    "Taste and adjust sweetness with more honey if needed",
                    "Pour into glasses and serve immediately",
                ],
                prepTime: 5,
                cookTime: 0,
                servings: 2,
                difficulty: .easy,
                tags: ["breakfast", "healthy", "smoothie", "quick", "vegetarian"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Beef Stew",
                description: "Hearty and comforting beef stew with root vegetables",
                ingredients: [
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Beef Chuck Roast",
                        quantity: 2.0,
                        unit: "lbs",
                        notes: "Cut into 2-inch cubes"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Potatoes",
                        quantity: 3.0,
                        unit: "pieces",
                        notes: "Large, peeled and cubed"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Carrots",
                        quantity: 4.0,
                        unit: "pieces",
                        notes: "Peeled and sliced"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Onion",
                        quantity: 1.0,
                        unit: "piece",
                        notes: "Large, diced"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Beef Broth",
                        quantity: 4.0,
                        unit: "cups",
                        notes: "Low sodium"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Tomato Paste",
                        quantity: 2.0,
                        unit: "tbsp",
                        notes: nil
                    ),
                ],
                instructions: [
                    "Season beef cubes with salt and pepper",
                    "Heat oil in a large pot and brown beef on all sides",
                    "Add onions and cook until softened, about 5 minutes",
                    "Stir in tomato paste and cook for 1 minute",
                    "Add beef broth and bring to a boil",
                    "Reduce heat to low, cover, and simmer for 1.5 hours",
                    "Add potatoes and carrots, cook for 30 minutes more",
                    "Season with salt and pepper to taste",
                ],
                prepTime: 20,
                cookTime: 150,
                servings: 6,
                difficulty: .medium,
                tags: ["comfort", "beef", "stew", "vegetables", "hearty", "winter"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Chocolate Chip Cookies",
                description: "Classic homemade chocolate chip cookies that are crispy on the outside and chewy inside",
                ingredients: [
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "All-Purpose Flour",
                        quantity: 2.25,
                        unit: "cups",
                        notes: nil
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Butter",
                        quantity: 1.0,
                        unit: "cup",
                        notes: "Softened"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Brown Sugar",
                        quantity: 0.75,
                        unit: "cup",
                        notes: "Packed"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "White Sugar",
                        quantity: 0.25,
                        unit: "cup",
                        notes: nil
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Eggs",
                        quantity: 2.0,
                        unit: "pieces",
                        notes: "Large"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Chocolate Chips",
                        quantity: 2.0,
                        unit: "cups",
                        notes: "Semi-sweet"
                    ),
                ],
                instructions: [
                    "Preheat oven to 375°F (190°C)",
                    "Cream together butter and both sugars until light and fluffy",
                    "Beat in eggs one at a time",
                    "Gradually mix in flour until just combined",
                    "Fold in chocolate chips",
                    "Drop rounded tablespoons of dough onto ungreased baking sheets",
                    "Bake for 9-11 minutes until golden brown",
                    "Cool on baking sheet for 2 minutes before transferring",
                ],
                prepTime: 15,
                cookTime: 25,
                servings: 36,
                difficulty: .easy,
                tags: ["dessert", "baking", "cookies", "chocolate", "sweet", "classic"]
            ),
            Recipe(
                id: UUID().uuidString,
                name: "Salmon Teriyaki",
                description: "Glazed salmon fillets with homemade teriyaki sauce",
                ingredients: [
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Salmon Fillets",
                        quantity: 4.0,
                        unit: "pieces",
                        notes: "6 oz each"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Soy Sauce",
                        quantity: 0.25,
                        unit: "cup",
                        notes: nil
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Mirin",
                        quantity: 2.0,
                        unit: "tbsp",
                        notes: nil
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Brown Sugar",
                        quantity: 2.0,
                        unit: "tbsp",
                        notes: nil
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Ginger",
                        quantity: 1.0,
                        unit: "tsp",
                        notes: "Fresh, grated"
                    ),
                    RecipeIngredient(
                        id: UUID().uuidString,
                        name: "Garlic",
                        quantity: 2.0,
                        unit: "cloves",
                        notes: "Minced"
                    ),
                ],
                instructions: [
                    "Combine soy sauce, mirin, brown sugar, ginger, and garlic",
                    "Marinate salmon fillets for 30 minutes",
                    "Preheat oven to 400°F (200°C)",
                    "Remove salmon from marinade, reserve liquid",
                    "Place salmon on baking sheet lined with parchment",
                    "Bake for 12-15 minutes until fish flakes easily",
                    "Meanwhile, simmer reserved marinade until thickened",
                    "Serve salmon glazed with reduced sauce",
                ],
                prepTime: 35,
                cookTime: 15,
                servings: 4,
                difficulty: .medium,
                tags: ["fish", "healthy", "asian", "protein", "teriyaki", "baked"]
            ),
        ]

        recipesStorage = recipes
        Self.logger.info("🌱 Seeded \(recipes.count) mock recipes")
    }
}

// MARK: - Recipe Service Errors

public enum RecipeServiceError: Error, LocalizedError {
    case recipeNotFound(String)
    case invalidData
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case let .recipeNotFound(id):
            return "Recipe with ID '\(id)' not found"
        case .invalidData:
            return "Invalid recipe data"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
