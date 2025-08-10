/*
 ListsTabView.swift
 JeevesKit

 Lists tab placeholder with nice empty state
 */

import SwiftUI

/// Lists tab view with placeholder content
public struct ListsTabView: View {
    @Environment(\.appState) private var appState
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: ListsTabViewModel?
    @State private var isLoading = true
    @State private var showingNewList = false

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                StandardLoadingView(showLogo: false)
            } else if let viewModel = viewModel {
                listsContent(viewModel: viewModel)
            } else {
                EmptyStateView(config: EmptyStateConfig(
                    icon: "exclamationmark.triangle",
                    title: L("error.service_unavailable"),
                    subtitle: L("error.service_unavailable_message", L("lists.service")),
                    actionTitle: L("error.retry"),
                    action: {
                        Task { await loadViewModel() }
                    }
                ))
            }
        }
        .navigationTitle(L("tabs.lists"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadViewModel()
        }
    }

    @ViewBuilder
    private func listsContent(viewModel: ListsTabViewModel) -> some View {
        ZStack {
            DesignTokens.Colors.Surface.primary
                .ignoresSafeArea()

            VStack {
                // The header is now handled by SharedHeaderToolbar

                if viewModel.isEmpty {
                    // Empty state content
                    EmptyStateView(config: EmptyStateConfig(
                        icon: AppSections.emptyStateIcon(for: .lists),
                        title: L("lists.empty"),
                        subtitle: L("lists.empty_message"),
                        actionTitle: L("lists.create"),
                        action: {
                            Task { @MainActor in
                                showingNewList = true
                            }
                        }
                    ))
                } else {
                    // Content with lists
                    shoppingListsContent(viewModel: viewModel)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task { @MainActor in
                        showingNewList = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignTokens.Colors.Primary.base)
                }
            }
        }
        .confirmationDialog(L("lists.create_list"), isPresented: $showingNewList) {
            Button(L("lists.type.shopping")) {
                Task {
                    await viewModel.createList(name: L("lists.new_shopping_list"))
                }
            }
            Button(L("lists.type.meal_plan")) {
                // TODO: Create meal plan in Phase 2
            }
            Button(L("lists.type.todo")) {
                // TODO: Create todo list in Phase 2
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("lists.create_list_prompt"))
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private func shoppingListsContent(viewModel: ListsTabViewModel) -> some View {
        List {
            ForEach(viewModel.displayedLists) { list in
                ShoppingListRow(list: list) {
                    // Handle list tap
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func loadViewModel() async {
        guard let factory = factory else {
            isLoading = false
            return
        }

        do {
            let newViewModel = try factory.makeListsTabViewModel()
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

struct ShoppingListRow: View {
    let list: ShoppingList
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)

                HStack {
                    Text(Lp("lists.items.count", list.items.count))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if completedItemsCount > 0 {
                        Text(L("lists.items.completed", completedItemsCount))
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Text(list.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var completedItemsCount: Int {
        list.items.filter(\.isCompleted).count
    }
}

#Preview {
    NavigationStack {
        ListsTabView()
    }
}
