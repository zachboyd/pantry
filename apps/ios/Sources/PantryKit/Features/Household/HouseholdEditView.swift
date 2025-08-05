/*
 HouseholdEditView.swift
 PantryKit

 View for editing household details
 */

import SwiftUI

/// View for editing household information
public struct HouseholdEditView: View {
    let householdId: String

    @Environment(\.dismiss) private var dismiss
    @State private var householdName = "The Smith Family"
    @State private var description = "Our family household"
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    public init(householdId: String) {
        self.householdId = householdId
    }

    private var isFormValid: Bool {
        !householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        // Mock comparison - in real app, compare with original values
        true
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("household.name"), text: $householdName)
                        .textInputAutocapitalization(.words)

                    TextField(L("household.description"), text: $description, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3, reservesSpace: true)
                } header: {
                    Text(L("household.edit.section_title"))
                } footer: {
                    Text(L("household.edit.section_footer"))
                }

                Section {
                    Button(L("household.delete"), role: .destructive) {
                        // TODO: Implement household deletion
                    }
                } footer: {
                    Text(L("household.delete.warning"))
                }
            }
            .navigationTitle(L("household.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("save")) {
                        saveChanges()
                    }
                    .disabled(!isFormValid || !hasChanges || isLoading)
                }
            }
            .alert(L("error"), isPresented: $showingAlert) {
                Button(L("ok")) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func saveChanges() {
        isLoading = true

        Task {
            do {
                // TODO: Implement actual household update
                try await Task.sleep(for: .seconds(1))

                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = L("household.edit.save_error")
                    showingAlert = true
                }
            }
        }
    }
}

#Preview {
    HouseholdEditView(householdId: "1")
}
