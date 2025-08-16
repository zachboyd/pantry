import Foundation

// MARK: - Shopping List Service Implementation

/// Service for managing shopping lists - mock implementation for MVP
@MainActor
public final class ShoppingListService: ShoppingListServiceProtocol {
    private static let logger = Logger.shopping

    private let householdService: HouseholdServiceProtocol
    private var listsStorage: [LowercaseUUID: [ShoppingList]] = [:]

    public init(householdService: HouseholdServiceProtocol) {
        self.householdService = householdService
        Self.logger.info("🛒 ShoppingListService initialized")
    }

    // MARK: - Public Methods

    public func getLists(for householdId: LowercaseUUID) async throws -> [ShoppingList] {
        Self.logger.info("📡 Getting shopping lists for household: \(householdId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let lists = listsStorage[householdId] ?? []
        Self.logger.info("✅ Retrieved \(lists.count) shopping lists")
        return lists
    }

    public func createList(name: String, householdId: LowercaseUUID) async throws -> ShoppingList {
        Self.logger.info("➕ Creating shopping list: \(name)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let newList = ShoppingList(
            id: LowercaseUUID(),
            householdId: householdId,
            name: name,
            items: [],
            createdBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Date(),
            updatedAt: Date(),
        )

        if listsStorage[householdId] == nil {
            listsStorage[householdId] = []
        }

        listsStorage[householdId]?.append(newList)
        Self.logger.info("✅ Created shopping list successfully")
        return newList
    }

    public func addItem(to listId: LowercaseUUID, item: ShoppingListItem) async throws {
        Self.logger.info("➕ Adding item to shopping list: \(listId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        var found = false
        for (householdId, var lists) in listsStorage {
            if let listIndex = lists.firstIndex(where: { $0.id == listId }) {
                var updatedList = lists[listIndex]
                var newItems = updatedList.items
                newItems.append(item)

                updatedList = ShoppingList(
                    id: updatedList.id,
                    householdId: updatedList.householdId,
                    name: updatedList.name,
                    items: newItems,
                    createdBy: updatedList.createdBy,
                    createdAt: updatedList.createdAt,
                    updatedAt: Date(),
                )

                lists[listIndex] = updatedList
                listsStorage[householdId] = lists
                found = true
                break
            }
        }

        guard found else {
            throw ShoppingListServiceError.listNotFound(listId.uuidString)
        }

        Self.logger.info("✅ Added item to shopping list successfully")
    }

    public func removeItem(from listId: LowercaseUUID, itemId: LowercaseUUID) async throws {
        Self.logger.info("🗑️ Removing item from shopping list: \(listId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        var found = false
        for (householdId, var lists) in listsStorage {
            if let listIndex = lists.firstIndex(where: { $0.id == listId }) {
                var updatedList = lists[listIndex]
                var newItems = updatedList.items

                if let itemIndex = newItems.firstIndex(where: { $0.id == itemId }) {
                    newItems.remove(at: itemIndex)

                    updatedList = ShoppingList(
                        id: updatedList.id,
                        householdId: updatedList.householdId,
                        name: updatedList.name,
                        items: newItems,
                        createdBy: updatedList.createdBy,
                        createdAt: updatedList.createdAt,
                        updatedAt: Date(),
                    )

                    lists[listIndex] = updatedList
                    listsStorage[householdId] = lists
                    found = true
                    break
                }
            }
        }

        guard found else {
            throw ShoppingListServiceError.itemNotFound(itemId.uuidString)
        }

        Self.logger.info("✅ Removed item from shopping list successfully")
    }

    // MARK: - Additional Methods

    public func toggleItemCompleted(listId: LowercaseUUID, itemId: LowercaseUUID) async throws {
        Self.logger.info("✅ Toggling item completion in list: \(listId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        var found = false
        for (householdId, var lists) in listsStorage {
            if let listIndex = lists.firstIndex(where: { $0.id == listId }) {
                var updatedList = lists[listIndex]
                var newItems = updatedList.items

                if let itemIndex = newItems.firstIndex(where: { $0.id == itemId }) {
                    let item = newItems[itemIndex]
                    let toggledItem = ShoppingListItem(
                        id: item.id,
                        name: item.name,
                        quantity: item.quantity,
                        unit: item.unit,
                        category: item.category,
                        isCompleted: !item.isCompleted,
                        addedBy: item.addedBy,
                        completedBy: item.isCompleted ? nil : LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001"),
                        completedAt: item.isCompleted ? nil : Date(),
                    )

                    newItems[itemIndex] = toggledItem

                    updatedList = ShoppingList(
                        id: updatedList.id,
                        householdId: updatedList.householdId,
                        name: updatedList.name,
                        items: newItems,
                        createdBy: updatedList.createdBy,
                        createdAt: updatedList.createdAt,
                        updatedAt: Date(),
                    )

                    lists[listIndex] = updatedList
                    listsStorage[householdId] = lists
                    found = true
                    break
                }
            }
        }

        guard found else {
            throw ShoppingListServiceError.itemNotFound(itemId.uuidString)
        }

        Self.logger.info("✅ Toggled item completion successfully")
    }

    public func deleteList(_ listId: LowercaseUUID) async throws {
        Self.logger.info("🗑️ Deleting shopping list: \(listId)")

        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        var found = false
        for (householdId, var lists) in listsStorage {
            if let index = lists.firstIndex(where: { $0.id == listId }) {
                lists.remove(at: index)
                listsStorage[householdId] = lists
                found = true
                break
            }
        }

        guard found else {
            throw ShoppingListServiceError.listNotFound(listId.uuidString)
        }

        Self.logger.info("✅ Deleted shopping list successfully")
    }

    // MARK: - Private Methods

    private func seedMockData() {
        let mockHouseholdId = LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let now = Date()

        let groceryItems = [
            ShoppingListItem(
                id: LowercaseUUID(),
                name: "Bread",
                quantity: 2.0,
                unit: "loaves",
                category: .pantry,
                isCompleted: false,
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                completedBy: nil,
                completedAt: nil,
            ),
            ShoppingListItem(
                id: LowercaseUUID(),
                name: "Eggs",
                quantity: 1.0,
                unit: "dozen",
                category: .dairy,
                isCompleted: true,
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                completedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001"),
                completedAt: Calendar.current.date(byAdding: .hour, value: -2, to: now),
            ),
            ShoppingListItem(
                id: LowercaseUUID(),
                name: "Apples",
                quantity: 3.0,
                unit: "lbs",
                category: .produce,
                isCompleted: false,
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                completedBy: nil,
                completedAt: nil,
            ),
        ]

        let weeklyShoppingItems = [
            ShoppingListItem(
                id: LowercaseUUID(),
                name: "Salmon",
                quantity: 2.0,
                unit: "fillets",
                category: .meat,
                isCompleted: false,
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                completedBy: nil,
                completedAt: nil,
            ),
            ShoppingListItem(
                id: LowercaseUUID(),
                name: "Spinach",
                quantity: 1.0,
                unit: "bag",
                category: .produce,
                isCompleted: false,
                addedBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                completedBy: nil,
                completedAt: nil,
            ),
        ]

        let mockLists = [
            ShoppingList(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Grocery Run",
                items: groceryItems,
                createdBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: now,
            ),
            ShoppingList(
                id: LowercaseUUID(),
                householdId: mockHouseholdId,
                name: "Weekly Shopping",
                items: weeklyShoppingItems,
                createdBy: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                createdAt: Calendar.current.date(byAdding: .day, value: -3, to: now) ?? now,
                updatedAt: now,
            ),
        ]

        listsStorage[mockHouseholdId] = mockLists
        Self.logger.info("🌱 Seeded \(mockLists.count) mock shopping lists")
    }
}

// MARK: - Shopping List Service Errors

public enum ShoppingListServiceError: Error, LocalizedError {
    case listNotFound(String)
    case itemNotFound(String)
    case householdNotFound(String)
    case invalidData
    case networkError(Error)

    public var errorDescription: String? {
        switch self {
        case let .listNotFound(id):
            "Shopping list with ID '\(id)' not found"
        case let .itemNotFound(id):
            "Shopping list item with ID '\(id)' not found"
        case let .householdNotFound(id):
            "Household with ID '\(id)' not found"
        case .invalidData:
            "Invalid shopping list data"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        }
    }
}
