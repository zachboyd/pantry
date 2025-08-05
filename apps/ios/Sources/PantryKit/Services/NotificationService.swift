import Foundation
@preconcurrency import UserNotifications

// MARK: - Notification Service Implementation

/// Service for managing local notifications - mock implementation for MVP
@MainActor
public final class NotificationService: NotificationServiceProtocol {
    private static let logger = Logger.notification

    private let notificationCenter: UNUserNotificationCenter
    private var scheduledNotifications: [String: UNNotificationRequest] = [:]

    public init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        Self.logger.info("🔔 NotificationService initialized")
    }

    // MARK: - Public Methods

    public func requestPermission() async throws -> Bool {
        Self.logger.info("📱 Requesting notification permission")

        let granted = try await notificationCenter.requestAuthorization(
            options: [.alert, .badge, .sound]
        )

        if granted {
            Self.logger.info("✅ Notification permission granted")
        } else {
            Self.logger.warning("⚠️ Notification permission denied")
        }

        return granted
    }

    public func scheduleExpirationNotification(for item: PantryItem) async throws {
        Self.logger.info("⏰ Scheduling expiration notification for: \(item.name)")

        guard let expirationDate = item.expirationDate else {
            Self.logger.warning("⚠️ Cannot schedule notification - no expiration date")
            return
        }

        // Check permission first
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            Self.logger.warning("⚠️ Notification permission not granted")
            throw NotificationServiceError.permissionDenied
        }

        // Schedule notification for 1 day before expiration
        let notificationDate = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: expirationDate
        ) ?? expirationDate

        // Don't schedule if the notification date is in the past
        guard notificationDate > Date() else {
            Self.logger.info("ℹ️ Notification date is in the past, skipping")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Item Expiring Soon"
        content.body = "\(item.name) expires tomorrow!"
        content.sound = .default
        content.categoryIdentifier = "EXPIRATION_REMINDER"
        content.userInfo = [
            "pantryItemId": item.id,
            "pantryItemName": item.name,
            "householdId": item.householdId,
        ]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notificationDate
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "expiration_\(item.id)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        scheduledNotifications["expiration_\(item.id)"] = request

        Self.logger.info("✅ Scheduled expiration notification for \(item.name)")
    }

    public func cancelNotification(for itemId: String) async throws {
        Self.logger.info("❌ Canceling notification for item: \(itemId)")

        let identifier = "expiration_\(itemId)"
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        scheduledNotifications.removeValue(forKey: identifier)

        Self.logger.info("✅ Canceled notification for item: \(itemId)")
    }

    // MARK: - Additional Methods

    public func scheduleShoppingReminder(for listName: String, householdId: String) async throws {
        Self.logger.info("🛒 Scheduling shopping reminder for: \(listName)")

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw NotificationServiceError.permissionDenied
        }

        let content = UNMutableNotificationContent()
        content.title = "Shopping Reminder"
        content.body = "Don't forget your \(listName) shopping list!"
        content.sound = .default
        content.categoryIdentifier = "SHOPPING_REMINDER"
        content.userInfo = [
            "listName": listName,
            "householdId": householdId,
        ]

        // Schedule for next day at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: false
        )

        let identifier = "shopping_\(householdId)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        scheduledNotifications[identifier] = request

        Self.logger.info("✅ Scheduled shopping reminder")
    }

    public func cancelAllNotifications() async {
        Self.logger.info("🧹 Canceling all notifications")

        notificationCenter.removeAllPendingNotificationRequests()
        scheduledNotifications.removeAll()

        Self.logger.info("✅ All notifications canceled")
    }

    public func getPendingNotifications() async -> [UNNotificationRequest] {
        Self.logger.info("📋 Getting pending notifications")

        let requests = await notificationCenter.pendingNotificationRequests()

        Self.logger.info("ℹ️ Found \(requests.count) pending notifications")
        return requests
    }

    public func getNotificationSettings() async -> UNNotificationSettings {
        return await notificationCenter.notificationSettings()
    }

    // MARK: - Notification Categories

    public func setupNotificationCategories() async {
        Self.logger.info("🏷️ Setting up notification categories")

        // Expiration reminder category
        let expirationActions = [
            UNNotificationAction(
                identifier: "VIEW_ITEM",
                title: "View Item",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "DISMISS",
                title: "Dismiss",
                options: []
            ),
        ]

        let expirationCategory = UNNotificationCategory(
            identifier: "EXPIRATION_REMINDER",
            actions: expirationActions,
            intentIdentifiers: [],
            options: []
        )

        // Shopping reminder category
        let shoppingActions = [
            UNNotificationAction(
                identifier: "VIEW_LIST",
                title: "View List",
                options: [.foreground]
            ),
            UNNotificationAction(
                identifier: "DISMISS",
                title: "Dismiss",
                options: []
            ),
        ]

        let shoppingCategory = UNNotificationCategory(
            identifier: "SHOPPING_REMINDER",
            actions: shoppingActions,
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            expirationCategory,
            shoppingCategory,
        ])

        Self.logger.info("✅ Notification categories set up")
    }

    // MARK: - Mock Behavior

    /// Mock method to simulate receiving a notification
    public func simulateExpirationNotification(for item: PantryItem) {
        Self.logger.info("🎭 Simulating expiration notification for: \(item.name)")
        // In a real app, this would be handled by the system
        // This is just for testing purposes
    }

    /// Mock method to get statistics
    public func getNotificationStats() -> NotificationStats {
        return NotificationStats(
            totalScheduled: scheduledNotifications.count,
            expirationReminders: scheduledNotifications.keys.filter { $0.hasPrefix("expiration_") }.count,
            shoppingReminders: scheduledNotifications.keys.filter { $0.hasPrefix("shopping_") }.count
        )
    }
}

// MARK: - Supporting Types

public struct NotificationStats {
    public let totalScheduled: Int
    public let expirationReminders: Int
    public let shoppingReminders: Int

    public init(totalScheduled: Int, expirationReminders: Int, shoppingReminders: Int) {
        self.totalScheduled = totalScheduled
        self.expirationReminders = expirationReminders
        self.shoppingReminders = shoppingReminders
    }
}

// MARK: - Notification Service Errors

public enum NotificationServiceError: Error, LocalizedError {
    case permissionDenied
    case schedulingFailed(Error)
    case invalidDate
    case notificationNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case let .schedulingFailed(error):
            return "Failed to schedule notification: \(error.localizedDescription)"
        case .invalidDate:
            return "Invalid notification date"
        case let .notificationNotFound(id):
            return "Notification with ID '\(id)' not found"
        }
    }
}
