import Foundation
import SwiftUI
import Observation
import CASLSwift

/// A reactive permission provider that ViewModels can observe for permission changes
/// This provides a clean, reusable way for any ViewModel to react to permission changes
@MainActor
@Observable
public final class PermissionProvider {
    // MARK: - Properties
    
    private let permissionService: PermissionServiceProtocol
    private let logger = Logger.permissions
    
    /// The current ability, observable by ViewModels
    public var currentAbility: PantryAbility? {
        permissionService.currentAbility
    }
    
    /// Check if permissions are loaded
    public var isLoaded: Bool {
        currentAbility != nil
    }
    
    // MARK: - Initialization
    
    public init(permissionService: PermissionServiceProtocol) {
        self.permissionService = permissionService
        logger.debug("PermissionProvider initialized")
    }
    
    // MARK: - Permission Checks with Logging
    
    /// Check if user can manage household members
    /// This is reactive and will cause views to update when permissions change
    public func canManageMembers(in householdId: String) -> Bool {
        guard let ability = currentAbility else {
            logger.info("No ability available for canManageMembers check")
            return false
        }
        
        let result = ability.canManageMembers(in: householdId)
        logger.info("Permission check - canManageMembers(\(householdId)): \(result)")
        return result
    }
    
    /// Check if user can manage a specific household
    public func canManageHousehold(_ householdId: String) -> Bool {
        guard let ability = currentAbility else {
            logger.info("No ability available for canManageHousehold check")
            return false
        }
        
        let result = ability.canManageHousehold(householdId)
        logger.info("Permission check - canManageHousehold(\(householdId)): \(result)")
        return result
    }
    
    /// Check if user can update a household
    public func canUpdateHousehold(_ householdId: String) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canUpdateHousehold(householdId)
    }
    
    /// Check if user can delete a household
    public func canDeleteHousehold(_ householdId: String) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canDeleteHousehold(householdId)
    }
    
    /// Check if user can create household members
    public func canCreateMembers(in householdId: String) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canSync(.create, .householdMember) ?? false
    }
    
    /// Check if user can update household members
    public func canUpdateMembers(in householdId: String) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canSync(.update, .householdMember) ?? false
    }
    
    /// Check if user can delete household members
    public func canDeleteMembers(in householdId: String) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canSync(.delete, .householdMember) ?? false
    }
    
    /// Generic permission check for any action and subject
    public func can(_ action: PantryAction, _ subject: PantrySubject) -> Bool {
        guard let ability = currentAbility else {
            return false
        }
        return ability.canSync(action, subject) ?? false
    }
}

// MARK: - Environment Key

private struct PermissionProviderKey: EnvironmentKey {
    static let defaultValue: PermissionProvider? = nil
}

public extension EnvironmentValues {
    /// Access the permission provider from the environment
    var permissionProvider: PermissionProvider? {
        get { self[PermissionProviderKey.self] }
        set { self[PermissionProviderKey.self] = newValue }
    }
}

// MARK: - View Modifier

public extension View {
    /// Inject the permission provider into the environment
    func withPermissionProvider(_ provider: PermissionProvider) -> some View {
        self.environment(\.permissionProvider, provider)
    }
}