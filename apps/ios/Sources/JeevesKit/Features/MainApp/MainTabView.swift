import SwiftUI

/// Main tab view with household context
public struct MainTabView: View {
    @Environment(\.appState) private var appState
    @Environment(\.sizeClassInfo) private var sizeClassInfo
    @State private var selectedTab: MainTab = .pantry

    // Separate navigation paths for each tab with @Bindable for improved iOS 18 navigation
    @State private var pantryPath = NavigationPath()
    @State private var chatPath = NavigationPath()
    @State private var listsPath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    // Track if we're showing no household state
    private var showNoHouseholdState: Bool {
        appState?.selectedHousehold == nil
    }

    // Sheet presentation states with @Bindable for two-way binding
    @State private var showingCreateHousehold = false
    @State private var showingJoinHousehold = false

    // iOS 26 liquid glass fix - force single re-render after appearance
    @State private var hasAppearedOnce = false

    public init() {}

    public var body: some View {
        Group {
            if showNoHouseholdState {
                NoHouseholdContentView(
                    showingCreateHousehold: $showingCreateHousehold,
                    showingJoinHousehold: $showingJoinHousehold,
                )
            } else if DeviceType.isiPad, sizeClassInfo.isRegular {
                // iPad split view layout
                iPadLayout
            } else {
                // iPhone/compact iPad layout
                iPhoneLayout
            }
        }
        .withSizeClassInfo()
        // iOS 26 liquid glass fix: Force exactly one re-render after first appearance
        // This is the minimal approach that actually works for the glass effect bug
        .id(hasAppearedOnce ? "rendered" : "initial")
        .onReceive(NotificationCenter.default.publisher(for: .householdChanged)) { _ in
            // Reset to first tab and all navigation paths when household changes
            selectedTab = .pantry
            pantryPath = NavigationPath()
            chatPath = NavigationPath()
            listsPath = NavigationPath()
            settingsPath = NavigationPath()
        }
        .onAppear {
            // Only trigger once, with a minimal delay to ensure glass effects are initialized
            if !hasAppearedOnce {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hasAppearedOnce = true
                }
            }
        }
        .sheet(isPresented: $showingCreateHousehold) {
            HouseholdCreationView()
        }
        .sheet(isPresented: $showingJoinHousehold) {
            NavigationStack {
                HouseholdJoinView(
                    onBack: { showingJoinHousehold = false },
                    onComplete: { _ in
                        showingJoinHousehold = false
                        // The household selection will be handled by hydration
                    },
                )
            }
        }
    }

    // MARK: - iPhone Layout

    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(MainTab.allCases.filter { $0 != .profile }, id: \.self) { tab in
                NavigationStack(path: navigationPath(for: tab)) {
                    tabContent(for: tab)
                        .sharedHeaderToolbar(title: tab.title)
                        .navigationDestination(for: NavigationDestination.self) { destination in
                            destinationView(for: destination)
                        }
                }
                .tabItem {
                    if tab.hasSymbolVariant {
                        Label(tab.title, systemImage: tab.iconName)
                            .environment(\.symbolVariants, .none)
                    } else {
                        Label(tab.title, systemImage: tab.iconName)
                    }
                }
                .tag(tab)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .tint(DesignTokens.Colors.Primary.base) // Set selected tab color
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            // iPad sidebar
            List {
                // User Profile Section
                Section {
                    HStack(spacing: 12) {
                        AvatarView(
                            user: appState?.currentUser,
                            size: .medium,
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState?.currentUser?.name ?? L("user.generic"))
                                .font(.headline)
                            Text(appState?.selectedHousehold?.name ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Show profile in detail view
                        selectedTab = .profile
                    }
                }

                // Tab Selection
                Section {
                    ForEach(MainTab.allCases.filter { $0 != .profile }, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            HStack {
                                Label(tab.title, systemImage: tab.iconName)
                                    .foregroundColor(tabLabelColor(for: tab))
                                Spacer()
                                if selectedTab == tab {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignTokens.Colors.Primary.base)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selectedTab == tab ? DesignTokens.Colors.Primary.light.opacity(0.2) : Color.clear)
                        .accessibilityIdentifier("sidebar_\(tab.rawValue)")
                    }
                }
            }
            .navigationTitle(L("app.name"))
            .navigationBarTitleDisplayMode(.large)
            .listStyle(.sidebar)
        } detail: {
            // iPad detail view
            NavigationStack(path: navigationPath(for: selectedTab)) {
                selectedTabView
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        destinationView(for: destination)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: MainTab) -> some View {
        switch tab {
        case .pantry:
            JeevesTabView(
                selectedHousehold: appState?.selectedHousehold,
                onSelectHousehold: { household in
                    appState?.selectHousehold(household)
                },
            )
        case .chat:
            ChatTabView()
        case .lists:
            ListsTabView()
        case .settings:
            HouseholdSettingsView(household: appState?.selectedHousehold)
        case .profile:
            let currentAppState = appState
            UserProfileView(
                currentUser: currentAppState?.currentUser,
                selectedHousehold: currentAppState?.selectedHousehold,
                households: [], // Will be loaded by ViewModel
                onSignOut: {
                    Logger.app.info("🚪 UserProfileView (tab) onSignOut callback invoked, appState: \(currentAppState != nil ? "exists" : "nil")")
                    if let appState = currentAppState {
                        await appState.signOut()
                    } else {
                        Logger.app.error("❌ AppState is nil in UserProfileView (tab) onSignOut")
                    }
                },
            )
        }
    }

    // MARK: - Selected Tab View

    @ViewBuilder
    private var selectedTabView: some View {
        tabContent(for: selectedTab)
    }

    // MARK: - Helper Methods

    /// Returns the appropriate navigation path binding for the selected tab
    private func navigationPath(for tab: MainTab) -> Binding<NavigationPath> {
        switch tab {
        case .pantry:
            $pantryPath
        case .chat:
            $chatPath
        case .lists:
            $listsPath
        case .settings:
            $settingsPath
        case .profile:
            // Profile doesn't have its own path in the current implementation
            $settingsPath
        }
    }

    /// Returns the appropriate color for tab labels based on selection state
    private func tabLabelColor(for tab: MainTab) -> Color {
        switch selectedTab == tab {
        case true:
            DesignTokens.Colors.Primary.base
        case false:
            DesignTokens.Colors.Text.primary
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        // Household Navigation
        case let .householdDetails(householdId):
            HouseholdDetailsView(householdId: householdId)
        case let .householdEdit(householdId):
            HouseholdEditView(householdId: householdId)
        case let .householdMembers(householdId):
            HouseholdMembersView(householdId: householdId)
        case .householdCreation:
            HouseholdCreationView()
        case .householdJoin:
            HouseholdJoinView(
                onBack: {
                    // Pop navigation
                },
                onComplete: { _ in
                    // Handle completion
                },
            )
        case .householdSwitcher:
            HouseholdSwitcherView(
                currentHouseholdId: appState?.selectedHousehold?.id,
                onSelectHousehold: { _ in
                    // Handle household selection through container
                },
            )
        // Profile Navigation
        case .userProfile:
            let currentAppState = appState
            UserProfileView(
                currentUser: currentAppState?.currentUser,
                selectedHousehold: currentAppState?.selectedHousehold,
                households: [], // Will be loaded by ViewModel
                onSignOut: {
                    Logger.app.info("🚪 UserProfileView signOut called, appState: \(currentAppState != nil ? "exists" : "nil")")
                    if let appState = currentAppState {
                        await appState.signOut()
                    } else {
                        Logger.app.error("❌ AppState is nil in UserProfileView signOut")
                    }
                },
            )
        case .appearanceSettings:
            AppearanceSettingsView()
        // Tab Navigation (shouldn't be used in navigation stack)
        case .pantryTab, .chatTab, .listsTab, .settingsTab:
            EmptyStateView(config: EmptyStateConfig(
                icon: "exclamationmark.triangle",
                title: L("error.generic_title"),
                subtitle: "Tab navigation should not be pushed",
                actionTitle: nil,
                action: nil,
            ))
        // Auth Navigation (shouldn't be used in main app)
        case .authentication, .onboarding:
            EmptyStateView(config: EmptyStateConfig(
                icon: "exclamationmark.triangle",
                title: L("error.generic_title"),
                subtitle: "Auth navigation not available here",
                actionTitle: nil,
                action: nil,
            ))
        }
    }
}

// MARK: - No Household Content View

@MainActor
private struct NoHouseholdContentView: View {
    @Binding var showingCreateHousehold: Bool
    @Binding var showingJoinHousehold: Bool

    var body: some View {
        EmptyStateView(config: AppSections.householdEmptyStateConfig(
            icon: AppSections.HouseholdIcons.noHousehold,
            titleKey: "household.no_household_selected",
            subtitleKey: "household.no_household_selected_message",
            actions: [
                EmptyStateAction(
                    title: L("household.create_new"),
                    style: .primary,
                    action: {
                        Task { @MainActor in
                            showingCreateHousehold = true
                        }
                    },
                ),
                EmptyStateAction(
                    title: L("household.join_existing"),
                    style: .secondary,
                    action: {
                        Task { @MainActor in
                            showingJoinHousehold = true
                        }
                    },
                ),
            ],
        ))
    }
}

// MARK: - Main Tab Enum

enum MainTab: String, CaseIterable, Hashable {
    case pantry
    case chat
    case lists
    case settings
    case profile // iPad only

    @MainActor
    var title: String {
        AppSections.label(for: appSection)
    }

    var iconName: String {
        AppSections.icon(for: appSection)
    }

    var hasSymbolVariant: Bool {
        AppSections.hasSymbolVariant(for: appSection)
    }

    var accessibilityIdentifier: String {
        AppSections.accessibilityIdentifier(for: appSection)
    }
}

// MARK: - Previews

#Preview("Main Tab View") {
    MainTabView()
        .withAppState()
}
