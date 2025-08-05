import SwiftUI

/// User profile view that displays user information and allows household switching
public struct UserProfileView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = UserProfileViewModel()
    
    @State private var showingSignOutConfirmation = false
    @State private var showingCreateHousehold = false
    @State private var showingJoinHousehold = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                // User Info Section
                userInfoSection
                
                // Households Section
                householdsSection
                
                // App Settings Section
                appSettingsSection
                
                // Sign Out Section
                signOutSection
            }
            .navigationTitle(L("settings.profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if let appState = appState {
                await viewModel.onAppear(appState: appState)
            }
        }
        .sheet(isPresented: $showingCreateHousehold) {
            HouseholdCreationView()
        }
        .sheet(isPresented: $showingJoinHousehold) {
            NavigationStack {
                HouseholdJoinView(
                    onBack: { showingJoinHousehold = false },
                    onComplete: { householdId in
                        showingJoinHousehold = false
                        if let appState = appState {
                            Task {
                                await viewModel.loadHouseholds(appState: appState)
                            }
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            L("sign.out"),
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .hidden
        ) {
            Button(L("sign.out"), role: .destructive) {
                Task {
                    if let appState = appState {
                        await viewModel.signOut(appState: appState)
                    }
                    dismiss()
                }
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("profile.signout.confirmation"))
        }
        .errorAlert(error: $viewModel.currentError)
    }
    
    // MARK: - User Info Section
    
    @ViewBuilder
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                AvatarView(
                    user: appState?.currentUser,
                    size: .large
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState?.currentUser?.name ?? L("user.unknown"))
                        .font(.headline)
                    
                    Text(appState?.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Households Section
    
    @ViewBuilder
    private var householdsSection: some View {
        Section {
            if viewModel.isLoadingHouseholds {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("household.loading"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.households) { household in
                    HouseholdRow(
                        household: household,
                        isSelected: household.id == appState?.currentHousehold?.id,
                        onTap: {
                            Task {
                                await switchHousehold(to: household)
                            }
                        }
                    )
                }
                
                // Create/Join Household Buttons
                Button(action: { showingCreateHousehold = true }) {
                    Label(L("household.create_new"), systemImage: "plus.circle")
                        .foregroundColor(.accentColor)
                }
                
                Button(action: { showingJoinHousehold = true }) {
                    Label(L("household.join_existing"), systemImage: "person.badge.plus")
                        .foregroundColor(.accentColor)
                }
            }
        } header: {
            Text(L("household.title"))
        } footer: {
            if let currentHousehold = appState?.currentHousehold {
                Text(L("profile.current_household", currentHousehold.name))
                    .font(.caption)
            }
        }
    }
    
    // MARK: - App Settings Section
    
    @ViewBuilder
    private var appSettingsSection: some View {
        Section(L("settings")) {
            NavigationLink(destination: AppearanceSettingsView()) {
                Label(L("settings.appearance"), systemImage: "paintbrush")
            }
            
            // Placeholder for future settings
            Label(L("settings.notifications"), systemImage: "bell")
                .foregroundColor(.secondary)
                .badge(L("coming.soon"))
            
            Label(L("settings.language"), systemImage: "globe")
                .foregroundColor(.secondary)
                .badge(L("coming.soon"))
        }
    }
    
    // MARK: - Sign Out Section
    
    @ViewBuilder
    private var signOutSection: some View {
        Section {
            Button(action: { showingSignOutConfirmation = true }) {
                HStack {
                    Spacer()
                    Label(L("sign.out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func switchHousehold(to household: Household) async {
        if let appState = appState {
            await viewModel.switchHousehold(to: household, appState: appState)
        }
        dismiss()
    }
}

// MARK: - Household Row

private struct HouseholdRow: View {
    let household: Household
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(household.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(Lp("household.members.count", household.memberCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - View Model

import Observation

@Observable
@MainActor
private final class UserProfileViewModel {
    var households: [Household] = []
    var isLoadingHouseholds = false
    var currentError: ViewModelError?
    
    func onAppear(appState: AppState) async {
        await loadHouseholds(appState: appState)
    }
    
    func loadHouseholds(appState: AppState) async {
        guard let householdService = appState.householdService else { return }
        
        isLoadingHouseholds = true
        defer { isLoadingHouseholds = false }
        
        do {
            households = try await householdService.getUserHouseholds()
        } catch {
            self.currentError = .operationFailed(L("household.load.error"))
            Logger.app.error("Failed to load households: \(error)")
        }
    }
    
    func switchHousehold(to household: Household, appState: AppState) async {
        await appState.switchHousehold(to: household)
    }
    
    func signOut(appState: AppState) async {
        await appState.signOut()
    }
}

// MARK: - Previews

#Preview("User Profile") {
    UserProfileView()
        .withAppState()
}