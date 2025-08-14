import Foundation
import Observation

// MARK: - ChatTabViewModel

/// ViewModel for the Chat tab - placeholder for household communication features
@Observable @MainActor
public final class ChatTabViewModel: BaseReactiveViewModel<ChatTabViewModel.State, ChatTabDependencies> {
    private static let logger = Logger.ui

    // MARK: - State

    public struct State: Sendable {
        var selectedHouseholdId: String?
        var householdName: String?
        var memberCount = 0
        var viewState: CommonViewState = .idle
        var showingError = false
        var errorMessage: String?
        var isFeatureEnabled = false

        // Placeholder data for future implementation
        var recentMessages: [ChatMessage] = []
        var unreadCount = 0
    }

    /// Placeholder message type for future implementation
    public struct ChatMessage: Identifiable, Sendable {
        public let id: String
        public let content: String
        public let senderId: String
        public let senderName: String
        public let timestamp: Date
        public let isFromCurrentUser: Bool

        public init(
            id: String,
            content: String,
            senderId: String,
            senderName: String,
            timestamp: Date,
            isFromCurrentUser: Bool
        ) {
            self.id = id
            self.content = content
            self.senderId = senderId
            self.senderName = senderName
            self.timestamp = timestamp
            self.isFromCurrentUser = isFromCurrentUser
        }
    }

    // MARK: - Computed Properties

    public var selectedHouseholdId: String? {
        state.selectedHouseholdId
    }

    public var householdName: String? {
        state.householdName
    }

    public var memberCount: Int {
        state.memberCount
    }

    public var isFeatureEnabled: Bool {
        state.isFeatureEnabled
    }

    public var recentMessages: [ChatMessage] {
        state.recentMessages
    }

    public var unreadCount: Int {
        state.unreadCount
    }

    public var hasHousehold: Bool {
        state.selectedHouseholdId != nil
    }

    public var isLoading: Bool {
        loadingStates.isAnyLoading
    }

    public var showingError: Bool {
        state.showingError
    }

    public var errorMessage: String? {
        state.errorMessage
    }

    public var placeholderTitle: String {
        if !hasHousehold {
            "No Household Selected"
        } else if !isFeatureEnabled {
            "Chat Coming Soon!"
        } else {
            "Household Chat"
        }
    }

    public var placeholderMessage: String {
        if !hasHousehold {
            "Select a household to start chatting with members."
        } else if !isFeatureEnabled {
            "Chat features are coming in a future update. Stay tuned!"
        } else {
            "Start a conversation with your household members."
        }
    }

    // MARK: - Initialization

    public required init(dependencies: ChatTabDependencies) {
        let initialState = State()
        super.init(dependencies: dependencies, initialState: initialState)
        Self.logger.info("💬 ChatTabViewModel initialized")

        // Set feature flag - this would come from a feature flag service
        updateState { $0.isFeatureEnabled = false }

        setupHouseholdObservation()
    }

    public required init(dependencies: ChatTabDependencies, initialState: State) {
        super.init(dependencies: dependencies, initialState: initialState)
        setupHouseholdObservation()
    }

    // MARK: - Lifecycle

    override public func onAppear() async {
        Self.logger.debug("👁️ ChatTabViewModel appeared")
        await super.onAppear()

        await loadSelectedHousehold()

        if isFeatureEnabled, let householdId = state.selectedHouseholdId {
            await loadChatData(for: householdId)
        }
    }

    override public func refresh() async {
        Self.logger.debug("🔄 ChatTabViewModel refresh")

        if isFeatureEnabled, let householdId = state.selectedHouseholdId {
            await loadChatData(for: householdId)
        }

        await super.refresh()
    }

    // MARK: - Public Methods

    /// Load chat data for a household (placeholder)
    public func loadChatData(for householdId: String) async {
        guard isFeatureEnabled else {
            Self.logger.info("💬 Chat feature not enabled, skipping data load")
            return
        }

        await executeTask(.load) { [weak self] in
            guard let self else { return }
            await performLoadChatData(for: householdId)
        }
    }

    /// Send a message (placeholder)
    public func sendMessage(_ content: String) async -> Bool {
        guard isFeatureEnabled else {
            Self.logger.warning("⚠️ Cannot send message - chat feature not enabled")
            return false
        }

        guard state.selectedHouseholdId != nil else {
            Self.logger.warning("⚠️ Cannot send message - no household selected")
            return false
        }

        Self.logger.info("💬 Sending message: \(content.prefix(50))...")

        // Placeholder implementation
        let result: Bool? = await executeTask(.send) {
            // Simulate sending message
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // This would be replaced with actual chat service call
            // try await self.dependencies.chatService.sendMessage(content, to: householdId)

            return true
        }

        return result == true
    }

    /// Mark messages as read (placeholder)
    public func markMessagesAsRead() async {
        guard isFeatureEnabled else { return }

        Self.logger.info("💬 Marking messages as read")

        await executeTask(.update) { [weak self] in
            guard let self else { return }
            // This would be replaced with actual chat service call
            // try await self.dependencies.chatService.markAsRead()

            await MainActor.run {
                self.updateState { $0.unreadCount = 0 }
            }
        }
    }

    /// Dismiss error
    public func dismissError() {
        updateState {
            $0.showingError = false
            $0.errorMessage = nil
        }
        clearError()
    }

    // MARK: - Private Methods

    private func setupHouseholdObservation() {
        // This would typically observe household changes from a service or coordinator
        // For now, we'll load the selected household from UserDefaults
        let selectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId")
        updateState { $0.selectedHouseholdId = selectedId }
    }

    private func loadSelectedHousehold() async {
        // Check for currently selected household
        let selectedId = UserDefaults.standard.string(forKey: "selectedHouseholdId")

        if selectedId != state.selectedHouseholdId {
            updateState { $0.selectedHouseholdId = selectedId }
            Self.logger.info("🏠 Selected household changed to: \(selectedId ?? "none")")

            // Load household info if we have an ID
            if let householdId = selectedId {
                await loadHouseholdInfo(householdId)
            } else {
                updateState {
                    $0.householdName = nil
                    $0.memberCount = 0
                }
            }
        }
    }

    private func loadHouseholdInfo(_ householdId: String) async {
        Self.logger.info("📡 Loading household info for chat: \(householdId)")

        do {
            let household = try await dependencies.householdService.getHousehold(id: householdId)

            updateState { state in
                state.householdName = household.name
                state.memberCount = household.memberCount
            }

            Self.logger.info("✅ Loaded household info: \(household.name)")

        } catch {
            Self.logger.error("❌ Failed to load household info: \(error)")
            // Don't show error for this background operation
        }
    }

    private func performLoadChatData(for householdId: String) async {
        Self.logger.info("📡 Loading chat data for household: \(householdId)")

        updateState { $0.viewState = .loading }

        // Placeholder: This would load actual chat messages
        // let messages = try await dependencies.chatService.getMessages(for: householdId)

        // For now, create some mock data
        let mockMessages = createMockMessages()

        updateState { state in
            state.recentMessages = mockMessages
            state.unreadCount = mockMessages.count(where: { !$0.isFromCurrentUser })
            state.viewState = mockMessages.isEmpty ? .empty : .loaded
        }

        Self.logger.info("✅ Loaded \(mockMessages.count) chat messages")
    }

    private func createMockMessages() -> [ChatMessage] {
        // This is just for UI development - remove when real chat is implemented
        [
            ChatMessage(
                id: "1",
                content: "Hey, we're running low on milk!",
                senderId: "user1",
                senderName: "Alice",
                timestamp: Date().addingTimeInterval(-3600),
                isFromCurrentUser: false,
            ),
            ChatMessage(
                id: "2",
                content: "I'll pick some up on my way home",
                senderId: "current",
                senderName: "You",
                timestamp: Date().addingTimeInterval(-1800),
                isFromCurrentUser: true,
            ),
            ChatMessage(
                id: "3",
                content: "Thanks! Also need bread if you see it",
                senderId: "user1",
                senderName: "Alice",
                timestamp: Date().addingTimeInterval(-900),
                isFromCurrentUser: false,
            ),
        ]
    }

    // MARK: - Error Handling Override

    override public func handleError(_ error: Error) {
        super.handleError(error)

        let errorMessage = error.localizedDescription
        updateState {
            $0.showingError = true
            $0.errorMessage = errorMessage
            $0.viewState = .error(currentError ?? .unknown(errorMessage))
        }
    }
}

// MARK: - Helper Extensions

public extension ChatTabViewModel {
    /// Check if chat is available for current state
    var isChatAvailable: Bool {
        hasHousehold && isFeatureEnabled
    }

    /// Get formatted member count string
    var memberCountText: String {
        switch memberCount {
        case 0:
            "No members"
        case 1:
            "1 member"
        default:
            "\(memberCount) members"
        }
    }
}
