import SwiftUI

/// View for inviting members to a household
public struct HouseholdInviteView: View {
    let householdId: String
    let householdName: String

    @State private var inviteCode: String = ""
    @State private var isGeneratingCode = false
    @State private var showingCopiedAlert = false

    public init(householdId: String, householdName: String) {
        self.householdId = householdId
        self.householdName = householdName
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text(L("household.invite_members"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(L("household.invite_members_message"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 32)

            // Invite Code Section
            VStack(spacing: 16) {
                if !inviteCode.isEmpty {
                    VStack(spacing: 12) {
                        Text(L("household.invite_code"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(inviteCode)
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.medium)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .onTapGesture {
                                copyInviteCode()
                            }

                        Button(action: copyInviteCode) {
                            Label(L("common.copy"), systemImage: "doc.on.doc")
                                .font(.callout)
                        }
                    }
                } else {
                    Button {
                        Task {
                            await generateInviteCode()
                        }
                    } label: {
                        if isGeneratingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(L("household.generate_invite_code"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGeneratingCode)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text(L("household.invite_instructions"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                VStack(alignment: .leading, spacing: 8) {
                    Label(L("household.invite_step1"), systemImage: "1.circle.fill")
                        .font(.caption)
                    Label(L("household.invite_step2"), systemImage: "2.circle.fill")
                        .font(.caption)
                    Label(L("household.invite_step3"), systemImage: "3.circle.fill")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle(L("household.invite_members"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("common.copied"), isPresented: $showingCopiedAlert) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            Text(L("household.invite_code_copied"))
        }
        .task {
            await loadOrGenerateInviteCode()
        }
    }

    // MARK: - Private Methods

    private func loadOrGenerateInviteCode() async {
        // TODO: Load existing invite code from backend
        // For now, generate a sample code
        await generateInviteCode()
    }

    private func generateInviteCode() async {
        isGeneratingCode = true

        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // TODO: Actually generate code via GraphQL
        // For now, generate a random code
        inviteCode = generateRandomCode()

        isGeneratingCode = false
    }

    private func generateRandomCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0 ..< 6).map { _ in letters.randomElement()! })
        let formatted = "\(String(code.prefix(3)))-\(String(code.suffix(3)))"
        return formatted
    }

    private func copyInviteCode() {
        UIPasteboard.general.string = inviteCode
        showingCopiedAlert = true
    }
}

// MARK: - Previews

#Preview("Invite Members") {
    NavigationStack {
        HouseholdInviteView(
            householdId: "123",
            householdName: "Smith Family"
        )
    }
}
