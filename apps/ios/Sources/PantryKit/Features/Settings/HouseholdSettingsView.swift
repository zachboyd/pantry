import SwiftUI

/// Settings view for household-specific settings
public struct HouseholdSettingsView: View {
    @Environment(\.appState) private var appState
    @State private var viewModel = HouseholdSettingsViewModel()

    public init() {}

    public var body: some View {
        List {
            // Household Info Section
            if let household = appState?.currentHousehold {
                householdInfoSection(household: household)
            }

            // Members Section
            membersSection

            // Household Preferences Section
            preferencesSection
        }
        .task {
            if let appState = appState {
                await viewModel.onAppear(appState: appState)
            }
        }
        .errorAlert(error: $viewModel.currentError)
    }

    // MARK: - Household Info Section

    @ViewBuilder
    private func householdInfoSection(household: Household) -> some View {
        Section {
            NavigationLink(destination: HouseholdEditView(householdId: household.id)) {
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
    private var membersSection: some View {
        Section {
            if let household = appState?.currentHousehold {
                NavigationLink(destination: HouseholdMembersView(householdId: household.id)) {
                    HStack {
                        Label(L("household.manage_members"), systemImage: "person.2")

                        Spacer()

                        Text("\(household.memberCount)")
                            .foregroundColor(.secondary)
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

// MARK: - View Model

import Observation

@Observable
@MainActor
private final class HouseholdSettingsViewModel {
    var isLoading = false
    var currentError: ViewModelError?

    func onAppear(appState _: AppState) async {
        // Future: Load household-specific settings
    }
}

// MARK: - Previews

#Preview("Household Settings") {
    NavigationStack {
        HouseholdSettingsView()
            .withAppState()
    }
}
