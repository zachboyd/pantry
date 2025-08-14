/*
 HouseholdDetailsView.swift
 JeevesKit

 View for displaying household details and management
 */

import SwiftUI

/// View for displaying household details
public struct HouseholdDetailsView: View {
    let householdId: String
    @State private var household: Household? = .mock // Mock data
    @State private var showingEdit = false
    @State private var showingInviteCode = false
    @State private var inviteCode = "PANTRY-ABC123"

    public init(householdId: String) {
        self.householdId = householdId
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if let household {
                    // Header
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        HStack {
                            Image(systemName: "house.fill")
                                .font(.system(size: 40))
                                .foregroundColor(DesignTokens.Colors.Primary.base)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(household.name)
                                    .font(DesignTokens.Typography.Semantic.pageTitle())
                                    .foregroundColor(DesignTokens.Colors.Text.primary)

                                Text(Lp("household.members.count", household.memberCount))
                                    .font(DesignTokens.Typography.Semantic.body())
                                    .foregroundColor(DesignTokens.Colors.Text.secondary)
                            }

                            Spacer()
                        }

                        // TODO: Add description when available in the model
                    }
                    .padding(DesignTokens.Spacing.Component.cardPadding)
                    .background(DesignTokens.Colors.Surface.secondary)
                    .cornerRadius(DesignTokens.BorderRadius.Component.card)

                    // Information cards
                    VStack(spacing: DesignTokens.Spacing.md) {
                        // Members card
                        NavigationLink(value: NavigationDestination.householdMembers(householdId: householdId)) {
                            HStack {
                                Image(systemName: "person.2")
                                    .foregroundColor(DesignTokens.Colors.Primary.base)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("household.members"))
                                        .font(DesignTokens.Typography.Semantic.cardTitle())
                                        .foregroundColor(DesignTokens.Colors.Text.primary)

                                    Text(L("household.members.subtitle"))
                                        .font(DesignTokens.Typography.Semantic.caption())
                                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(DesignTokens.Colors.Text.tertiary)
                            }
                            .padding(DesignTokens.Spacing.Component.cardPadding)
                            .background(DesignTokens.Colors.Surface.secondary)
                            .cornerRadius(DesignTokens.BorderRadius.Component.card)
                        }
                        .buttonStyle(.plain)

                        // Invite members card
                        if household.isCurrentUserOwner {
                            Button(action: { showingInviteCode = true }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(DesignTokens.Colors.Secondary.base)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L("household.invite_members"))
                                            .font(DesignTokens.Typography.Semantic.cardTitle())
                                            .foregroundColor(DesignTokens.Colors.Text.primary)

                                        Text(L("household.invite_members.subtitle"))
                                            .font(DesignTokens.Typography.Semantic.caption())
                                            .foregroundColor(DesignTokens.Colors.Text.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(DesignTokens.Colors.Text.tertiary)
                                }
                                .padding(DesignTokens.Spacing.Component.cardPadding)
                                .background(DesignTokens.Colors.Surface.secondary)
                                .cornerRadius(DesignTokens.BorderRadius.Component.card)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if household.isCurrentUserOwner {
                        // Management section
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text(L("household.management"))
                                .font(DesignTokens.Typography.Semantic.sectionHeader())
                                .foregroundColor(DesignTokens.Colors.Text.primary)

                            Button(action: { showingEdit = true }) {
                                HStack {
                                    Image(systemName: "pencil")
                                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                                        .frame(width: 24)

                                    Text(L("household.edit"))
                                        .font(DesignTokens.Typography.Semantic.body())
                                        .foregroundColor(DesignTokens.Colors.Text.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(DesignTokens.Colors.Text.tertiary)
                                }
                                .padding(DesignTokens.Spacing.Component.cardPadding)
                                .background(DesignTokens.Colors.Surface.secondary)
                                .cornerRadius(DesignTokens.BorderRadius.Component.card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    // Loading state
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(DesignTokens.Spacing.Layout.screenEdge)
        }
        .navigationTitle(L("household.details.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEdit) {
            if let household {
                NavigationStack {
                    HouseholdEditView(householdId: household.id)
                }
            }
        }
        .sheet(isPresented: $showingInviteCode) {
            InviteCodeSheet(inviteCode: inviteCode)
        }
    }
}

/// Sheet for displaying and sharing invite code
struct InviteCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let inviteCode: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.xl) {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundColor(DesignTokens.Colors.Primary.base)

                    Text(L("household.invite_code"))
                        .font(DesignTokens.Typography.Semantic.pageTitle())
                        .foregroundColor(DesignTokens.Colors.Text.primary)

                    Text(L("household.invite_code.share_message"))
                        .font(DesignTokens.Typography.Semantic.body())
                        .foregroundColor(DesignTokens.Colors.Text.secondary)
                        .multilineTextAlignment(.center)
                }

                // Invite code display
                VStack(spacing: DesignTokens.Spacing.md) {
                    Text(inviteCode)
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .foregroundColor(DesignTokens.Colors.Text.primary)
                        .padding(DesignTokens.Spacing.lg)
                        .background(DesignTokens.Colors.Surface.secondary)
                        .cornerRadius(DesignTokens.BorderRadius.Component.card)

                    PrimaryButton(L("household.invite_code.copy")) {
                        UIPasteboard.general.string = inviteCode
                    }
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.Layout.screenEdge)
            .navigationTitle(L("household.invite_members"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        HouseholdDetailsView(householdId: "1")
    }
}
