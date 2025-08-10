import Foundation

/// Example demonstrating JSON serialization features in CASLSwift
@MainActor
func serializationExample() async throws {
    
    // MARK: - Creating Permissions from JSON
    
    // Example 1: Simple permissions array (CASL format)
    let simplePermissionsJSON = """
    [
        {
            "action": "read",
            "subject": "Household"
        },
        {
            "action": "manage",
            "subject": "Household",
            "conditions": {
                "ownerId": "${userId}"
            }
        },
        {
            "action": "delete",
            "subject": "Recipe",
            "inverted": true,
            "reason": "Users cannot delete recipes"
        }
    ]
    """
    
    // Create ability from JSON string
    let ability = try PureAbility.from(jsonString: simplePermissionsJSON)
    
    // Check permissions
    print("Can read any household:", ability.can("read", "Household"))
    print("Cannot delete recipes:", ability.cannot("delete", "Recipe"))
    
    // MARK: - Using AbilityBuilder with JSON
    
    let builder = PureAbilityBuilder()
    
    // Add some rules programmatically
    builder
        .can("create", "ShoppingList")
        .can("update", "ShoppingList", ["householdId": "${currentHouseholdId}"])
    
    // Then add more rules from JSON
    let additionalPermissionsJSON = """
    [
        {
            "action": "invite",
            "subject": "User",
            "conditions": {
                "role": "admin"
            }
        }
    ]
    """
    
    try builder.from(jsonString: additionalPermissionsJSON)
    
    // Build the ability
    let combinedAbility = builder.build()
    
    // MARK: - Exporting Permissions
    
    // Export as simple JSON array
    let exportedJSON = try await combinedAbility.toJSONString()
    print("Exported permissions:", exportedJSON)
    
    // Export as PermissionSet with metadata
    let metadata: [String: Any] = [
        "userId": "user123",
        "generatedAt": Date().ISO8601Format(),
        "appVersion": "1.0.0"
    ]
    
    let permissionSetData = try await combinedAbility.toPermissionSet(
        version: "1.0",
        metadata: metadata
    )
    
    let permissionSetJSON = String(data: permissionSetData, encoding: .utf8)!
    print("Permission set with metadata:", permissionSetJSON)
    
    // MARK: - Working with Array Actions/Subjects (CASL Format)
    
    let arrayPermissionsJSON = """
    [
        {
            "action": ["read", "update"],
            "subject": "Post",
            "conditions": {
                "authorId": "${userId}"
            }
        },
        {
            "action": "manage",
            "subject": ["Post", "Comment"],
            "fields": "content"
        },
        {
            "action": "moderate"
        }
    ]
    """
    
    let arrayAbility = try PureAbility.from(jsonString: arrayPermissionsJSON)
    
    // The first permission expands to two rules internally
    print("Can read posts:", await arrayAbility.can("read", "Post"))
    print("Can update posts:", await arrayAbility.can("update", "Post"))
    
    // Claim-based rule (no subject)
    print("Can moderate:", await arrayAbility.can("moderate", "all"))
    
    // MARK: - Working with Complex Conditions
    
    let complexPermissionsJSON = """
    {
        "version": "1.0",
        "permissions": [
            {
                "action": "update",
                "subject": "Recipe",
                "conditions": {
                    "$or": [
                        { "ownerId": "${userId}" },
                        { "sharedWith": { "$in": ["${userId}"] } }
                    ],
                    "status": { "$ne": "archived" }
                },
                "fields": ["title", "ingredients", "instructions"]
            },
            {
                "action": "publish",
                "subject": "Recipe",
                "conditions": {
                    "ownerId": "${userId}",
                    "status": "draft",
                    "isComplete": true
                }
            }
        ]
    }
    """
    
    let complexAbility = try PureAbility.from(jsonString: complexPermissionsJSON)
    
    // MARK: - Error Handling
    
    // Handle invalid JSON
    let invalidJSON = "{ invalid json"
    do {
        _ = try PureAbility.from(jsonString: invalidJSON)
    } catch let error as PermissionError {
        print("Permission error:", error.errorDescription ?? "Unknown error")
    }
    
    // Handle unsupported version
    let unsupportedVersionJSON = """
    {
        "version": "99.0",
        "permissions": []
    }
    """
    
    do {
        _ = try PermissionCoder.decodePermissionSet(
            from: unsupportedVersionJSON.data(using: .utf8)!
        )
    } catch PermissionError.unsupportedVersion(let version) {
        print("Unsupported version:", version)
    }
    
    // MARK: - Updating Permissions Dynamically
    
    // Create an ability
    let dynamicAbility = PureAbility()
    
    // Load initial permissions
    try await dynamicAbility.update(fromJSONString: simplePermissionsJSON)
    
    // Later, update with new permissions (replaces all existing rules)
    let updatedPermissionsJSON = """
    [
        {
            "action": "manage",
            "subject": "all"
        }
    ]
    """
    
    try await dynamicAbility.update(fromJSONString: updatedPermissionsJSON)
    
    // Now user can manage everything
    print("Can manage households:", await dynamicAbility.can("update", "Household"))
    print("Can manage recipes:", await dynamicAbility.can("delete", "Recipe"))
}

// MARK: - JeevesKit Integration Example

/// Example showing how JeevesKit would use the JSON serialization
struct JeevesKitIntegrationExample {
    
    @MainActor
    static func loadUserPermissions(from userData: UserData) async throws -> PureAbility {
        // Assume UserData has a permissions field with JSON string
        guard let permissionsJSON = userData.permissions else {
            // Return default ability with no permissions
            return PureAbility()
        }
        
        // Create ability from the JSON permissions
        let ability = try PureAbility.from(jsonString: permissionsJSON)
        
        // Optionally cache to disk for offline access
        let cacheURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("permissions.json")
        
        try permissionsJSON.write(to: cacheURL, atomically: true, encoding: .utf8)
        
        return ability
    }
    
    @MainActor
    static func loadCachedPermissions() -> PureAbility? {
        let cacheURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("permissions.json")
        
        guard let permissionsJSON = try? String(contentsOf: cacheURL) else {
            return nil
        }
        
        return try? PureAbility.from(jsonString: permissionsJSON)
    }
}

// Mock user data for example
struct UserData {
    let id: String
    let permissions: String?
}