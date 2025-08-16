/*
 HouseholdEditView.swift
 JeevesKit

 View for editing household details
 */

import SwiftUI

/// View for editing household information
public struct HouseholdEditView: View {
    private static let logger = Logger.household

    let householdId: LowercaseUUID
    let isReadOnly: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.safeViewModelFactory) private var factory
    @State private var viewModel: HouseholdEditViewModel?

    public init(householdId: LowercaseUUID, isReadOnly: Bool = false) {
        self.householdId = householdId
        self.isReadOnly = isReadOnly
    }

    public var body: some View {
        NavigationStack {
            if let viewModel {
                Form {
                    Section {
                        if viewModel.isReadOnly {
                            // Read-only mode - show as text
                            HStack {
                                Text(L("household.name"))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(viewModel.name)
                            }

                            if !viewModel.description.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L("household.description"))
                                        .foregroundColor(.secondary)
                                    Text(viewModel.description)
                                }
                            }
                        } else {
                            // Edit mode - show text fields
                            TextField(L("household.name"), text: Binding(
                                get: { viewModel.name },
                                set: { viewModel.name = $0 },
                            ))
                            .textInputAutocapitalization(.words)

                            TextField(L("household.description"), text: Binding(
                                get: { viewModel.description },
                                set: { viewModel.description = $0 },
                            ), axis: .vertical)
                                .textInputAutocapitalization(.sentences)
                                .lineLimit(3, reservesSpace: true)
                        }
                    } header: {
                        Text(L("household.edit.section_title"))
                    } footer: {
                        if !viewModel.isReadOnly {
                            Text(L("household.edit.section_footer"))
                        }
                    }
                }
                .navigationTitle(viewModel.isReadOnly ? L("household.view.title") : L("household.edit.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if !viewModel.isReadOnly {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(L("save")) {
                                Task {
                                    if await viewModel.save() {
                                        dismiss()
                                    }
                                }
                            }
                            .disabled(!viewModel.canSave)
                        }
                    }
                }
                .alert(L("error"), isPresented: Binding(
                    get: { viewModel.showingError },
                    set: { _ in viewModel.dismissError() },
                )) {
                    Button(L("ok")) {
                        viewModel.dismissError()
                    }
                } message: {
                    Text(viewModel.errorMessage ?? L("error.generic"))
                }
                .alert(L("household.edit.coming_soon.title"), isPresented: Binding(
                    get: { viewModel.showingComingSoon },
                    set: { _ in viewModel.dismissComingSoon() },
                )) {
                    Button(L("ok")) {
                        viewModel.dismissComingSoon()
                    }
                } message: {
                    Text(L("household.edit.coming_soon.message"))
                }
                .overlay {
                    if viewModel.showLoadingIndicator {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.3))
                    }
                }
            } else {
                ProgressView()
                    .navigationTitle(isReadOnly ? L("household.view.title") : L("household.edit.title"))
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            do {
                viewModel = try factory?.makeHouseholdEditViewModel(
                    householdId: householdId,
                    mode: .edit,
                    isReadOnly: isReadOnly,
                )
                await viewModel?.onAppear()
            } catch {
                Self.logger.error("Failed to create HouseholdEditViewModel: \(error)")
            }
        }
    }
}

#Preview {
    HouseholdEditView(householdId: LowercaseUUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
}
