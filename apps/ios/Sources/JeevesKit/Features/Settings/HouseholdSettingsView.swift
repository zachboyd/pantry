import SwiftUI

/// Settings view for household-specific settings
public struct HouseholdSettingsView: View {
    @Environment(\.safeViewModelFactory) private var factory
    @State private var settingsViewModel: UserSettingsViewModel?

    let household: Household?

    public init(household: Household? = nil) {
        self.household = household
    }

    public var body: some View {
        List {
            // Household Info Section
            if let household {
                householdInfoSection(household: household)

                // Members Section
                membersSection(household: household)
            }

            // Household Preferences Section
            preferencesSection
        }
        .navigationTitle(L("settings.household"))
        .task {
            // Create ViewModel if needed
            if settingsViewModel == nil {
                settingsViewModel = try? factory?.makeUserSettingsViewModel()
            }

            await settingsViewModel?.onAppear()
        }
        .onDisappear {
            Task {
                await settingsViewModel?.onDisappear()
            }
        }
    }

    // MARK: - Household Info Section

    @ViewBuilder
    private func householdInfoSection(household: Household) -> some View {
        Section {
            // For demonstration: Show read-only view if user is not owner/admin
            // In a real app, you'd check actual permissions here
            NavigationLink(destination: HouseholdEditView(householdId: household.id, isReadOnly: false)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("household.name"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(household.name)
                            .font(.body)
                    }

                    Spacer()
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("household.created"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(household.createdAt, style: .date)
                        .font(.body)
                }

                Spacer()
            }
        } header: {
            Text(L("household.information"))
        }
    }

    // MARK: - Members Section

    @ViewBuilder
    private func membersSection(household: Household) -> some View {
        Section {
            NavigationLink(destination: HouseholdMembersView(householdId: household.id)) {
                HStack {
                    Label(L("household.manage_members"), systemImage: "person.2")

                    Spacer()

                    Text("\(household.memberCount)")
                        .foregroundColor(.secondary)
                }
            }

            // Only show invite member option if user has permission to manage members
            if settingsViewModel?.canCreateHouseholdMember(for: household.id) == true {
                NavigationLink(destination: HouseholdInviteView(householdId: household.id, householdName: household.name)) {
                    HStack {
                        Label(L("household.invite_member"), systemImage: "person.badge.plus")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                }
            }

        } header: {
            Text(L("household.members"))
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private var preferencesSection: some View {
        Section {
            // Placeholder for future household preferences
            HStack {
                Label(L("household.shopping_day"), systemImage: "calendar")
                Spacer()
                Text(L("common.not_set"))
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(L("household.default_store"), systemImage: "cart")
                Spacer()
                Text(L("common.not_set"))
                    .foregroundColor(.secondary)
            }

            HStack {
                Label(L("household.meal_planning"), systemImage: "fork.knife")
                Spacer()
                Text(L("household.meal_planning.weekly"))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text(L("household.preferences"))
        } footer: {
            Text(L("household.preferences.coming_soon"))
                .font(.caption)
        }
    }
}

// MARK: - Previews

#Preview("Household Settings") {
    NavigationStack {
        HouseholdSettingsView()
            .withAppState()
    }
}
