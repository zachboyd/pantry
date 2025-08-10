/*
 JeevesTabView.swift
 JeevesKit

 Jeeves tab placeholder with nice empty state
 */

import SwiftUI

/// Jeeves tab view with placeholder content
public struct JeevesTabView: View {
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: JeevesTabViewModel?
    @State private var isLoading = true

    // MARK: - Parameters

    let currentHousehold: Household?
    let onSelectHousehold: (Household) -> Void

    public init(
        currentHousehold: Household? = nil,
        onSelectHousehold: @escaping (Household) -> Void = { _ in }
    ) {
        self.currentHousehold = currentHousehold
        self.onSelectHousehold = onSelectHousehold
    }

    public var body: some View {
        Group {
            if isLoading {
                StandardLoadingView(showLogo: false)
            } else if let viewModel = viewModel {
                pantryContent(viewModel: viewModel)
            } else {
                EmptyStateView(config: EmptyStateConfig(
                    icon: "exclamationmark.triangle",
                    title: L("error.generic_title"),
                    subtitle: L("error.generic_message"),
                    actionTitle: L("error.try_again"),
                    action: {
                        Task { await loadViewModel() }
                    }
                ))
            }
        }
        .navigationTitle(L("tabs.pantry"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadViewModel()
        }
        .onChange(of: currentHousehold?.id) { _, _ in
            viewModel?.setHousehold(currentHousehold)
        }
    }

    @ViewBuilder
    private func pantryContent(viewModel: JeevesTabViewModel) -> some View {
        ZStack {
            DesignTokens.Colors.Surface.primary
                .ignoresSafeArea()

            VStack {
                // The header is now handled by SharedHeaderToolbar

                if viewModel.isEmpty {
                    // Empty state content
                    EmptyStateView(config: EmptyStateConfig(
                        icon: AppSections.emptyStateIcon(for: .pantry),
                        title: L("pantry.empty"),
                        subtitle: L("pantry.empty_message"),
                        actionTitle: L("pantry.add_first_item"),
                        action: {
                            Task { @MainActor in
                                viewModel.showAddItemSheet()
                            }
                        }
                    ))
                } else {
                    // Content with items
                    pantryItemsList(viewModel: viewModel)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { @MainActor in
                        viewModel.showAddItemSheet()
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignTokens.Colors.Primary.base)
                }
                .accessibilityIdentifier(AccessibilityUtilities.Identifier.addButton)
                .accessibilityLabel(L("pantry.add_item"))
                .accessibilityHint(AccessibilityUtilities.Hint.addIngredient)
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showingAddItemSheet },
            set: { _ in viewModel.hideAddItemSheet() }
        )) {
            addIngredientSheet()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .alert(L("error"), isPresented: Binding(
            get: { viewModel.showingError },
            set: { _ in viewModel.dismissError() }
        )) {
            Button(L("ok")) {
                viewModel.dismissError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private func pantryItemsList(viewModel: JeevesTabViewModel) -> some View {
        List {
            ForEach(viewModel.displayedItems) { item in
                ItemRow(item: item) {
                    // Handle item tap
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func addIngredientSheet() -> some View {
        NavigationStack {
            VStack {
                Text(L("pantry.add_item"))
                    .font(DesignTokens.Typography.Semantic.pageTitle())
                    .padding()
                Text(L("coming.soon"))
                    .foregroundColor(DesignTokens.Colors.Text.secondary)
                Spacer()
            }
            .navigationTitle(L("pantry.add_item"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L("cancel")) {
                        viewModel?.hideAddItemSheet()
                    }
                }
            }
        }
    }

    private func loadViewModel() async {
        guard let factory = factory else {
            isLoading = false
            return
        }

        do {
            let newViewModel = try factory.makeJeevesTabViewModel()

            // Set the current household
            newViewModel.setHousehold(currentHousehold)

            await newViewModel.onAppear()

            await MainActor.run {
                self.viewModel = newViewModel
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct ItemRow: View {
    let item: Item
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                HStack {
                    Text("\(String(format: "%.1f", item.quantity)) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let expirationDate = item.expirationDate {
                        Text(expirationDate, style: .date)
                            .font(.caption)
                            .foregroundColor(expirationDate < Date() ? .red : .secondary)
                    }
                }
            }

            Spacer()

            VStack {
                Image(systemName: categoryIcon(for: item.category))
                    .foregroundColor(DesignTokens.Colors.Primary.base)

                Text(item.category.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func categoryIcon(for category: ItemCategory) -> String {
        switch category {
        case .produce: return "leaf"
        case .dairy: return "drop"
        case .meat: return "fish"
        case .pantry: return "archivebox"
        case .frozen: return "snowflake"
        case .beverages: return "cup.and.saucer"
        case .other: return "questionmark.circle"
        }
    }
}

#Preview {
    NavigationStack {
        JeevesTabView()
    }
}
