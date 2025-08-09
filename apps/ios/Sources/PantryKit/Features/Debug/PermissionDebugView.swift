import SwiftUI
import CASLSwift

/// Debug view to display current permissions and test permission evaluation
public struct PermissionDebugView: View {
    @Environment(\.permissionProvider) private var permissionProvider
    @Environment(\.appState) private var appState
    @State private var testHouseholdId = ""
    @State private var testResults: [String] = []
    
    private let logger = Logger.permissions
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                Section("Current User") {
                    if let user = appState?.currentUser {
                        LabeledContent("User ID", value: user.id)
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if let name = user.name {
                            LabeledContent("Name", value: name)
                        }
                    } else {
                        Text("No current user")
                    }
                }
                
                Section("Current Household") {
                    if let household = appState?.currentHousehold {
                        LabeledContent("Household ID", value: household.id)
                        LabeledContent("Name", value: household.name)
                        
                        Button("Test Permissions for Current Household") {
                            testHouseholdId = household.id
                            testPermissions()
                        }
                    } else {
                        Text("No current household")
                    }
                }
                
                Section("Permission Provider Status") {
                    if let provider = permissionProvider {
                        LabeledContent("Provider Available", value: "✅")
                        LabeledContent("Permissions Loaded", value: provider.isLoaded ? "✅" : "❌")
                    } else {
                        Text("❌ No permission provider available")
                    }
                }
                
                Section("Test Specific Household") {
                    TextField("Household ID", text: $testHouseholdId)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Test Permissions") {
                        testPermissions()
                    }
                    .disabled(testHouseholdId.isEmpty)
                }
                
                if !testResults.isEmpty {
                    Section("Test Results for: \(testHouseholdId)") {
                        ForEach(testResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(result.contains("✅") ? .green : 
                                               result.contains("❌") ? .red : .primary)
                        }
                    }
                }
                
                Section("Raw Permissions") {
                    if let ability = permissionProvider?.currentAbility {
                        Button("Log All Rules to Console") {
                            logAllRules(ability: ability)
                        }
                        Text("Check console for detailed permission rules")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No ability loaded")
                    }
                }
            }
            .navigationTitle("Permission Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func testPermissions() {
        guard let provider = permissionProvider, !testHouseholdId.isEmpty else {
            testResults = ["❌ Provider not available or no household ID"]
            return
        }
        
        var results: [String] = []
        
        // Test all household-related permissions
        let canManageHousehold = provider.canManageHousehold(testHouseholdId)
        results.append("canManageHousehold: \(canManageHousehold ? "✅" : "❌")")
        
        let canUpdateHousehold = provider.canUpdateHousehold(testHouseholdId)
        results.append("canUpdateHousehold: \(canUpdateHousehold ? "✅" : "❌")")
        
        let canDeleteHousehold = provider.canDeleteHousehold(testHouseholdId)
        results.append("canDeleteHousehold: \(canDeleteHousehold ? "✅" : "❌")")
        
        let canManageMembers = provider.canManageMembers(in: testHouseholdId)
        results.append("canManageMembers: \(canManageMembers ? "✅" : "❌")")
        
        let canCreateMembers = provider.canCreateMembers(in: testHouseholdId)
        results.append("canCreateMembers: \(canCreateMembers ? "✅" : "❌")")
        
        let canUpdateMembers = provider.canUpdateMembers(in: testHouseholdId)
        results.append("canUpdateMembers: \(canUpdateMembers ? "✅" : "❌")")
        
        let canDeleteMembers = provider.canDeleteMembers(in: testHouseholdId)
        results.append("canDeleteMembers: \(canDeleteMembers ? "✅" : "❌")")
        
        // Test generic permissions
        let canManageAnyHousehold = provider.can(.manage, .household)
        results.append("canManage ANY household: \(canManageAnyHousehold ? "✅" : "❌")")
        
        let canManageAnyMember = provider.can(.manage, .householdMember)
        results.append("canManage ANY member: \(canManageAnyMember ? "✅" : "❌")")
        
        testResults = results
        
        // Also log to console for debugging
        logger.info("📊 Permission test results for household \(testHouseholdId):")
        for result in results {
            logger.info("  \(result)")
        }
    }
    
    private func logAllRules(ability: PantryAbility) {
        logger.info("📋 ========== ALL PERMISSION RULES ==========")
        
        // Note: This is a simplified version. In a real implementation,
        // you'd need to access the actual rules from the ability.
        // For now, we'll just test some common patterns.
        
        let testActions: [PantryAction] = [.create, .read, .update, .delete, .manage]
        let testSubjects: [PantrySubject] = [.user, .household, .householdMember, .message, .pantry, .all]
        
        for action in testActions {
            for subject in testSubjects {
                let canPerform = ability.canSync(action, subject) ?? false
                if canPerform {
                    logger.info("  ✅ CAN \(action.rawValue) \(subject.rawValue)")
                }
            }
        }
        
        logger.info("📋 ========================================")
    }
}

// MARK: - Preview

struct PermissionDebugView_Previews: PreviewProvider {
    static var previews: some View {
        PermissionDebugView()
    }
}