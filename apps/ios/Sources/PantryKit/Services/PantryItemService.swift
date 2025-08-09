import Foundation

// MARK: - Pantry Item Service Implementation

/// Service for managing pantry items - mock implementation for MVP
@MainActor
public final class PantryItemService: PantryItemServiceProtocol {
    private static let logger = Logger.pantry

    private let householdService: HouseholdServiceProtocol
    private var itemsStorage: [String: [PantryItem]] = [:]

    public init(householdService: HouseholdServiceProtocol) {
        self.householdService = householdService
        Self.logger.info("🥫 PantryItemService initialized")
    }

    // MARK: - Public Methods

    public func getItems(for householdId: String) async throws -> [PantryItem] {
        Self.logger.info("📡 Getting pantry items for household: \(householdId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let items = itemsStorage[householdId] ?? []
        Self.logger.info("✅ Retrieved \(items.count) pantry items")
        return items
    }

    public func addItem(_ item: PantryItem) async throws {
        Self.logger.info("➕ Adding pantry item: \(item.name)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        if itemsStorage[item.householdId] == nil {
            itemsStorage[item.householdId] = []
        }

        itemsStorage[item.householdId]?.append(item)
        Self.logger.info("✅ Added pantry item successfully")
    }

    public func updateItem(_ item: PantryItem) async throws {
        Self.logger.info("✏️ Updating pantry item: \(item.name)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        guard var items = itemsStorage[item.householdId] else {
            throw PantryItemServiceError.itemNotFound(item.id)
        }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            throw PantryItemServiceError.itemNotFound(item.id)
        }

        items[index] = item
        itemsStorage[item.householdId] = items
        Self.logger.info("✅ Updated pantry item successfully")
    }

    public func deleteItem(id: String) async throws {
        Self.logger.info("🗑️ Deleting pantry item: \(id)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        var found = false
        for (householdId, var items) in itemsStorage {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items.remove(at: index)
                itemsStorage[householdId] = items
                found = true
                break
            }
        }

        guard found else {
            throw PantryItemServiceError.itemNotFound(id)
        }

        Self.logger.info("✅ Deleted pantry item successfully")
    }

    // MARK: - Private Methods

    private func seedMockData() {
        let mockHouseholdId = "mock_household_1"
        let now = Date()

        let mockItems = [
            PantryItem(
                id: UUID().uuidString,
                householdId: mockHouseholdId,
                name: "Milk",
                quantity: 1.0,
                unit: "gallon",
                category: .dairy,
                expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: now),
                location: "Refrigerator",
                notes: "2% milk",
                addedBy: "mock_user_1",
                createdAt: now,
                updatedAt: now
            ),
            PantryItem(
                id: UUID().uuidString,
                householdId: mockHouseholdId,
                name: "Bananas",
                quantity: 6.0,
                unit: "pieces",
                category: .produce,
                expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: now),
                location: "Counter",
                notes: "Getting ripe",
                addedBy: "mock_user_1",
                createdAt: now,
                updatedAt: now
            ),
            PantryItem(
                id: UUID().uuidString,
                householdId: mockHouseholdId,
                name: "Chicken Breast",
                quantity: 2.0,
                unit: "lbs",
                category: .meat,
                expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: now),
                location: "Refrigerator",
                notes: "Organic, free-range",
                addedBy: "mock_user_1",
                createdAt: now,
                updatedAt: now
            ),
            PantryItem(
                id: UUID().uuidString,
                householdId: mockHouseholdId,
                name: "Rice",
                quantity: 5.0,
                unit: "lbs",
                category: .pantry,
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: now),
                location: "Pantry",
                notes: "Jasmine rice",
                addedBy: "mock_user_1",
                createdAt: now,
                updatedAt: now
            ),
            PantryItem(
                id: UUID().uuidString,
                householdId: mockHouseholdId,
                name: "Frozen Peas",
                quantity: 1.0,
                unit: "bag",
                category: .frozen,
                expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: now),
                location: "Freezer",
                notes: "Organic",
                addedBy: "mock_user_1",
                createdAt: now,
                updatedAt: now
            ),
        ]

        itemsStorage[mockHouseholdId] = mockItems
        Self.logger.info("🌱 Seeded \(mockItems.count) mock pantry items")
    }
}

// MARK: - Pantry Item Service Errors

public enum PantryItemServiceError: Error, LocalizedError {
    case itemNotFound(String)
    case householdNotFound(String)
    case invalidData
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case let .itemNotFound(id):
            return "Pantry item with ID '\(id)' not found"
        case let .householdNotFound(id):
            return "Household with ID '\(id)' not found"
        case .invalidData:
            return "Invalid pantry item data"
        case let .networkError(error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
