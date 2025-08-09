import Foundation

// MARK: - Example Types for Pantry App

/// Actions available in the Pantry app
public enum PantryAction: String {
    case create
    case read
    case update
    case delete
    case manage
    case invite
    case join
    case leave
    case changeRole
}

/// Subject types in the Pantry app
public enum PantrySubject: String {
    case household = "Household"
    case pantryItem = "PantryItem"
    case shoppingList = "ShoppingList"
    case recipe = "Recipe"
    case member = "Member"
    case user = "User"
}

// MARK: - Example Subjects

/// Example Household subject
public struct Household: Subject, IdentifiableSubject, Sendable {
    public static let subjectType: SubjectType = "Household"
    
    public let id: String
    public let name: String
    public let ownerId: String
    public let memberCount: Int
    
    public var subjectType: SubjectType { Self.subjectType }
}

/// Example User subject
public struct User: Subject, IdentifiableSubject, Sendable {
    public static let subjectType: SubjectType = "User"
    
    public let id: String
    public let email: String
    public let name: String
    
    public var subjectType: SubjectType { Self.subjectType }
}

// MARK: - Ability Type Alias

/// Type alias for Pantry-specific Ability
public typealias PantryAbility = Ability<PantryAction, PantrySubject>

// MARK: - Example Usage

/// Example of building abilities for different user roles
public func buildAbilitiesForUser(_ user: User, role: String) -> PantryAbility {
    let builder = AbilityBuilder<PantryAction, PantrySubject>()
    
    switch role {
    case "owner":
        // Owners can do everything
        builder
            .can(.manage, .household)
            .can(.manage, .pantryItem)
            .can(.manage, .shoppingList)
            .can(.manage, .recipe)
            .can(.manage, .member)
        
    case "admin":
        // Admins can manage most things but not delete household
        builder
            .can(.create, .pantryItem)
            .can(.read, .pantryItem)
            .can(.update, .pantryItem)
            .can(.delete, .pantryItem)
            .can(.manage, .shoppingList)
            .can(.manage, .recipe)
            .can(.invite, .member)
            .can(.changeRole, .member)
            .cannot(.delete, .household)
        
    case "member":
        // Members have limited access
        builder
            .can(.read, .household)
            .can(.read, .pantryItem)
            .can(.create, .pantryItem)
            .can(.update, .pantryItem) { ["createdBy": user.id] }
            .can(.delete, .pantryItem) { ["createdBy": user.id] }
            .can(.read, .shoppingList)
            .can(.update, .shoppingList)
            .can(.read, .recipe)
            .can(.create, .recipe)
            .can(.update, .recipe) { ["authorId": user.id] }
            .can(.leave, .household)
        
    case "viewer":
        // Viewers can only read
        builder
            .can(.read, .household)
            .can(.read, .pantryItem)
            .can(.read, .shoppingList)
            .can(.read, .recipe)
        
    default:
        // No permissions
        break
    }
    
    return builder.build()
}

/// Example of using PureAbility for dynamic permissions
public func buildDynamicAbilities(permissions: [[String: Any]]) -> PureAbility {
    let builder = PureAbilityBuilder()
    
    for permission in permissions {
        guard let action = permission["action"] as? String,
              let subject = permission["subject"] as? String else {
            continue
        }
        
        let inverted = permission["inverted"] as? Bool ?? false
        let conditions = permission["conditions"] as? [String: Any]
        let fields = permission["fields"] as? [String]
        
        if inverted {
            if let conditions = conditions {
                builder.cannot(action, subject, conditions)
            } else {
                builder.cannot(action, subject)
            }
        } else {
            if let fields = fields {
                builder.can(action, subject, fields: fields)
            } else if let conditions = conditions {
                builder.can(action, subject, conditions)
            } else {
                builder.can(action, subject)
            }
        }
    }
    
    return builder.build()
}