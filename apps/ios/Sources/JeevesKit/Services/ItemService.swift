import Foundation

// MARK: - Item Service Implementation

/// Service for managing pantry items - mock implementation for MVP
@MainActor
public final class ItemService: ItemServiceProtocol {
    private static let logger = Logger.jeeves

    private let householdService: HouseholdServiceProtocol
    private var itemsStorage: [LowercaseUUID: [Item]] = [:]

    public init(householdService: HouseholdServiceProtocol) {
        self.householdService = householdService
        Self.logger.info("🥫 ItemService initialized")
    }

    // MARK: - Public Methods

    public func getItems(for householdId: LowercaseUUID) async throws -> [Item] {
        Self.logger.info("📡 Getting pantry items for household: \(householdId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let items = itemsStorage[householdId] ?? []
        Self.logger.info("✅ Retrieved \(items.count) pantry items")
        return items
    }

    public func addItem(_ item: Item) async throws {
        Self.logger.info("➕ Adding pantry item: \(item.name)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        if itemsStorage[item.householdId] == nil {
            itemsStorage[item.householdId] = []
        }

        itemsStorage[item.householdId]?.append(item)
        Self.logger.info("✅ Added pantry item successfully")
    }

    public func updateItem(_ item: Item) async throws {
        Self.logger.info("✏️ Updating pantry item: \(item.name)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        guard var items = itemsStorage[item.householdId] else {
            throw ItemServiceError.itemNotFound(item.id.uuidString)
        }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            throw ItemServiceError.itemNotFound(item.id.uuidString)
        }

        items[index] = item
        itemsStorage[item.householdId] = items
        Self.logger.info("✅ Updated pantry item successfully")
    }

    public func deleteItem(id: LowercaseUUID) async throws {
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
            throw ItemServiceError.itemNotFound(id.uuidString)
        }

        Self.logger.info("✅ Deleted pantry item successfully")
    }

    // MARK: - Private Methods

    private func seedMockData() {
        let mockHouseholdId = LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let now = Date()

        let mockItems = [
            Item(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Milk",
                quantity: 1.0,
                unit: "gallon",
                category: .dairy,
                expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: now),
                location: "Refrigerator",
                notes: "2% milk",
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: now,
                updatedAt: now,
            ),
            Item(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Bananas",
                quantity: 6.0,
                unit: "pieces",
                category: .produce,
                expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: now),
                location: "Counter",
                notes: "Getting ripe",
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: now,
                updatedAt: now,
            ),
            Item(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Chicken Breast",
                quantity: 2.0,
                unit: "lbs",
                category: .meat,
                expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: now),
                location: "Refrigerator",
                notes: "Organic, free-range",
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: now,
                updatedAt: now,
            ),
            Item(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Rice",
                quantity: 5.0,
                unit: "lbs",
                category: .pantry,
                expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: now),
                location: "Pantry",
                notes: "Jasmine rice",
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: now,
                updatedAt: now,
            ),
            Item(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Frozen Peas",
                quantity: 1.0,
                unit: "bag",
                category: .frozen,
                expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: now),
                location: "Freezer",
                notes: "Organic",
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                createdAt: now,
                updatedAt: now,
            ),
        ]

        itemsStorage[mockHouseholdId] = mockItems
        Self.logger.info("🌱 Seeded \(mockItems.count) mock pantry items")
    }
}

// MARK: - Item Service Errors

public enum ItemServiceError: Error, LocalizedError {
    case itemNotFound(String)
    case householdNotFound(String)
    case invalidData
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case let .itemNotFound(id):
            "Item with ID '\(id)' not found"
        case let .householdNotFound(id):
            "Household with ID '\(id)' not found"
        case .invalidData:
            "Invalid pantry item data"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        }
    }
}
