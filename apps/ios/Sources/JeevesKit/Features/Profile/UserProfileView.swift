import SwiftUI

/// User profile view that displays user information and allows household switching
public struct UserProfileView: View {
    @Environment(\.safeViewModelFactory) private var viewModelFactory
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UserSettingsViewModel?

    let currentUser: User?
    let currentHousehold: Household?
    let households: [Household]
    let onSignOut: () async -> Void
    let onSelectHousehold: (Household) -> Void

    public init(
        currentUser: User? = nil,
        currentHousehold: Household? = nil,
        households: [Household] = [],
        onSignOut: @escaping () async -> Void = {},
        onSelectHousehold: @escaping (Household) -> Void = { _ in }
    ) {
        self.currentUser = currentUser
        self.currentHousehold = currentHousehold
        self.households = households
        self.onSignOut = onSignOut
        self.onSelectHousehold = onSelectHousehold
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    // Check watched data loading state
                    if viewModel.currentUserWatch.isLoading, viewModel.currentUserWatch.value == nil {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.watchedDataError {
                        ProfileErrorView(
                            error: error,
                            onRetry: {
                                Task {
                                    await viewModel.retryFailedWatches()
                                }
                            },
                        )
                    } else {
                        profileContent
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
            if viewModel == nil {
                viewModel = try? viewModelFactory?.makeUserSettingsViewModel()
            }
            await viewModel?.onAppear()
        }
        .onDisappear {
            Task {
                await viewModel?.onDisappear()
            }
        }
        .confirmationDialog(
            L("sign.out"),
            isPresented: Binding(
                get: { viewModel?.showingSignOutConfirmation ?? false },
                set: { _ in viewModel?.hideSignOutConfirmation() },
            ),
            titleVisibility: .hidden,
        ) {
            Button(L("sign.out"), role: .destructive) {
                Task {
                    Logger.app.info("🚪 UserProfileView sign out button pressed")
                    await onSignOut()
                    Logger.app.info("✅ UserProfileView onSignOut callback completed")
                    dismiss()
                }
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("profile.signout.confirmation"))
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private var profileContent: some View {
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
    }

    // MARK: - User Info Section

    @ViewBuilder
    private var userInfoSection: some View {
        Section {
            HStack(spacing: 16) {
                AvatarView(
                    user: viewModel?.currentUser ?? currentUser,
                    size: .large,
                )

                VStack(alignment: .leading, spacing: 4) {
                    // Use watched data
                    Text(viewModel?.currentUser?.name ?? currentUser?.name ?? L("user.unknown"))
                        .font(.headline)

                    Text(viewModel?.currentUser?.email ?? currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Show loading indicator if user data is being refreshed
                if viewModel?.currentUserWatch.isLoading == true {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Households Section

    @ViewBuilder
    private var householdsSection: some View {
        Section {
            // Show loading state for households
            if viewModel?.householdsWatch.isLoading == true, viewModel?.householdsWatch.value == nil {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L("household.loading"))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if let displayHouseholds = viewModel?.userHouseholds ?? (households.isEmpty ? nil : households), !displayHouseholds.isEmpty {
                ForEach(displayHouseholds) { household in
                    HouseholdRow(
                        household: household,
                        isSelected: household.id == currentHousehold?.id,
                        onTap: {
                            onSelectHousehold(household)
                            dismiss()
                        },
                    )
                }

                // Create/Join buttons
                NavigationLink {
                    HouseholdCreationView(
                        showBackButton: true,
                        onComplete: { _ in
                            Task {
                                await viewModel?.refresh()
                            }
                            dismiss()
                        },
                    )
                } label: {
                    Label(L("household.create_new"), systemImage: "plus.circle")
                        .foregroundColor(.accentColor)
                }

                NavigationLink {
                    HouseholdJoinView(
                        showBackButton: true,
                        onBack: { dismiss() },
                        onComplete: { _ in
                            Task {
                                await viewModel?.refresh()
                            }
                            dismiss()
                        },
                    )
                } label: {
                    Label(L("household.join_existing"), systemImage: "person.badge.plus")
                        .foregroundColor(.accentColor)
                }
            } else {
                // Empty state
                Text(L("household.no_households"))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)

                NavigationLink {
                    HouseholdCreationView(
                        showBackButton: true,
                        onComplete: { _ in
                            Task {
                                await viewModel?.refresh()
                            }
                            dismiss()
                        },
                    )
                } label: {
                    Label(L("household.create_new"), systemImage: "plus.circle")
                        .foregroundColor(.accentColor)
                }

                NavigationLink {
                    HouseholdJoinView(
                        showBackButton: true,
                        onBack: { dismiss() },
                        onComplete: { _ in
                            Task {
                                await viewModel?.refresh()
                            }
                            dismiss()
                        },
                    )
                } label: {
                    Label(L("household.join_existing"), systemImage: "person.badge.plus")
                        .foregroundColor(.accentColor)
                }
            }
        } header: {
            HStack {
                Text(L("household.title"))
                Spacer()
                if viewModel?.householdsWatch.isLoading == true {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        } footer: {
            if let household = currentHousehold {
                Text(L("profile.current_household", household.name))
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
            Button(action: { viewModel?.showSignOutConfirmation() }) {
                HStack {
                    Spacer()
                    Label(L("sign.out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        }
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

// MARK: - Profile Error View

private struct ProfileErrorView: View {
    let error: Error
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(L("error.generic_title"))
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Label(L("retry"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("User Profile") {
    UserProfileView()
        .withAppState()
}
