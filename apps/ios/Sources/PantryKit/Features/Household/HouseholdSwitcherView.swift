/*
 HouseholdSwitcherView.swift
 PantryKit

 View for switching between households
 */

import SwiftUI

/// View for switching between user's households
public struct HouseholdSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var households: [Household] = Household.mockHouseholds
    @State private var showingCreateHousehold = false
    @State private var showingJoinHousehold = false
    
    let currentHouseholdId: String?
    let onSelectHousehold: (Household) -> Void

    public init(
        currentHouseholdId: String?,
        onSelectHousehold: @escaping (Household) -> Void
    ) {
        self.currentHouseholdId = currentHouseholdId
        self.onSelectHousehold = onSelectHousehold
    }

    public var body: some View {
        NavigationStack {
            List {
                // Current households
                Section {
                    ForEach(households) { household in
                        HouseholdRowView(
                            household: household,
                            isSelected: household.id == currentHouseholdId,
                            onSelect: {
                                selectHousehold(household)
                            }
                        )
                    }
                } header: {
                    Text(L("household.switcher.your_households"))
                }

                // Actions
                Section {
                    Button(action: { showingCreateHousehold = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.Colors.Primary.base)

                            Text(L("household.create_new"))
                                .foregroundColor(DesignTokens.Colors.Text.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { showingJoinHousehold = true }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(DesignTokens.Colors.Secondary.base)

                            Text(L("household.join_existing"))
                                .foregroundColor(DesignTokens.Colors.Text.primary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text(L("household.switcher.actions"))
                }
            }
            .navigationTitle(L("household.switcher.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateHousehold) {
            NavigationView {
                HouseholdCreationView(
                    onBack: { showingCreateHousehold = false },
                    onComplete: { _ in
                        showingCreateHousehold = false
                        // TODO: Refresh households list
                    }
                )
            }
        }
        .sheet(isPresented: $showingJoinHousehold) {
            NavigationView {
                HouseholdJoinView(
                    onBack: { showingJoinHousehold = false },
                    onComplete: { _ in
                        showingJoinHousehold = false
                        // TODO: Refresh households list
                    }
                )
            }
        }
    }

    private func selectHousehold(_ household: Household) {
        onSelectHousehold(household)
        dismiss()
    }
}

/// Row view for displaying a household in the switcher
struct HouseholdRowView: View {
    let household: Household
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(household.name)
                            .font(DesignTokens.Typography.Semantic.cardTitle())
                            .foregroundColor(DesignTokens.Colors.Text.primary)

                        if household.isCurrentUserOwner {
                            Text(L("household.role.owner"))
                                .font(DesignTokens.Typography.Semantic.caption())
                                .foregroundColor(DesignTokens.Colors.Primary.base)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignTokens.Colors.Primary.light)
                                .cornerRadius(4)
                        }
                    }

                    Text(Lp("household.members.count", household.members.count))
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.tertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.Primary.base)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Household Extensions

// Extensions moved to Household model in DependencyContainer.swift

#Preview {
    HouseholdSwitcherView(
        currentHouseholdId: "1",
        onSelectHousehold: { _ in }
    )
}
