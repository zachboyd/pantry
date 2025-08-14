/*
 ChatTabView.swift
 JeevesKit

 Chat tab placeholder with nice empty state
 */

import SwiftUI

/// Chat tab view with placeholder content
public struct ChatTabView: View {
    @Environment(\.appState) private var appState
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: ChatTabViewModel?
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                StandardLoadingView(showLogo: false)
            } else if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                EmptyStateView(config: EmptyStateConfig(
                    icon: "exclamationmark.triangle",
                    title: L("error.service_unavailable"),
                    subtitle: L("error.service_unavailable_message", L("chat.service")),
                    actionTitle: L("error.retry"),
                    action: {
                        Task { await loadViewModel() }
                    },
                ))
            }
        }
        .navigationTitle(L("tabs.chat"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadViewModel()
        }
    }

    @ViewBuilder
    private func chatContent(viewModel _: ChatTabViewModel) -> some View {
        ZStack {
            DesignTokens.Colors.Surface.primary
                .ignoresSafeArea()

            VStack {
                // The header is now handled by SharedHeaderToolbar

                // Empty state content for Phase 1
                EmptyStateView(config: EmptyStateConfig(
                    icon: AppSections.emptyStateIcon(for: .chat),
                    title: L("chat.empty"),
                    subtitle: L("chat.empty_message"),
                    actionTitle: L("chat.send_message"),
                    action: {
                        // TODO: Implement messaging in Phase 2
                    },
                ))
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // TODO: Implement messaging in Phase 2
                }) {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(DesignTokens.Colors.Primary.base)
                }
            }
        }
    }

    private func loadViewModel() async {
        guard let factory else {
            isLoading = false
            return
        }

        do {
            let newViewModel = try factory.makeChatTabViewModel()
            await newViewModel.onAppear()

            await MainActor.run {
                viewModel = newViewModel
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatTabView()
    }
}
