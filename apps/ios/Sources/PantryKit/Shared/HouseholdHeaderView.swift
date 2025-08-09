/*
 HouseholdHeaderView.swift
 PantryKit

 Header component showing current household info
 */

import SwiftUI

/// Header showing current household information
public struct HouseholdHeaderView: View {
    let household: Household
    let onSelectHousehold: ((Household) -> Void)?
    @State private var showingHouseholdSwitcher = false

    public init(
        household: Household,
        onSelectHousehold: ((Household) -> Void)? = nil
    ) {
        self.household = household
        self.onSelectHousehold = onSelectHousehold
    }

    public var body: some View {
        Button(action: { showingHouseholdSwitcher = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(household.name)
                        .font(DesignTokens.Typography.Semantic.cardTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)
                        .lineLimit(1)

                    Text(Lp("household.members.count", household.memberCount))
                        .font(DesignTokens.Typography.Semantic.caption())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.Text.tertiary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.Layout.screenEdge)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Surface.secondary)
        .sheet(isPresented: $showingHouseholdSwitcher) {
            NavigationStack {
                HouseholdSwitcherView(
                    currentHouseholdId: household.id,
                    onSelectHousehold: { selectedHousehold in
                        onSelectHousehold?(selectedHousehold)
                        showingHouseholdSwitcher = false
                    }
                )
            }
        }
    }
}

// MARK: - Household Model Extension

// Household model is defined in DependencyContainer.swift with memberCount and isCurrentUserOwner
// Extensions moved to centralized location to avoid redeclaration conflicts

#Preview {
    HouseholdHeaderView(household: .mock)
}
