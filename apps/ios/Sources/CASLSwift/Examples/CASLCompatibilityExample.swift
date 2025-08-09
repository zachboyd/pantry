import Foundation

/// Example demonstrating exact compatibility with CASL's JavaScript format
/// This ensures permissions from a CASL backend work seamlessly with CASLSwift
@MainActor
func caslCompatibilityExample() async throws {
    
    // MARK: - Real-World CASL Backend Response
    
    // This is the exact format that would come from a CASL JavaScript backend
    let backendPermissionsJSON = """
    [
        {
            "action": "read",
            "subject": "Article"
        },
        {
            "action": ["create", "read", "update"],
            "subject": "Article",
            "conditions": {
                "authorId": "${userId}"
            }
        },
        {
            "action": "delete",
            "subject": "Article",
            "conditions": {
                "authorId": "${userId}",
                "status": { "$ne": "published" }
            }
        },
        {
            "action": "publish",
            "subject": "Article",
            "conditions": {
                "authorId": "${userId}",
                "status": "draft"
            },
            "fields": ["status"]
        },
        {
            "action": "manage",
            "subject": ["Comment", "Like"],
            "conditions": {
                "articleAuthorId": "${userId}"
            }
        },
        {
            "action": "moderate"
        },
        {
            "action": "delete",
            "subject": "Comment",
            "inverted": true,
            "conditions": {
                "flagCount": { "$gte": 5 }
            },
            "reason": "Highly flagged comments cannot be deleted, only hidden"
        }
    ]
    """
    
    // Parse the permissions exactly as they come from the backend
    let ability = try PureAbility.from(jsonString: backendPermissionsJSON)
    
    // MARK: - Key Format Differences from Original Implementation
    
    print("=== Key CASL Format Features ===")
    
    // 1. Actions can be arrays - expands to multiple rules
    print("1. Array actions expand to multiple rules:")
    print("   Can create articles:", ability.can("create", "Article"))
    print("   Can update articles:", ability.can("update", "Article"))
    
    // 2. Subjects can be arrays - applies to multiple types
    print("\n2. Array subjects apply to multiple types:")
    print("   Can manage comments:", ability.can("manage", "Comment"))
    print("   Can manage likes:", ability.can("manage", "Like"))
    
    // 3. Subject is optional for claim-based rules
    print("\n3. Claim-based rules have no subject:")
    print("   Can moderate (no subject):", ability.can("moderate", "all"))
    
    // 4. Fields can be a single string or array
    print("\n4. Fields can be string or array")
    // The example shows array, but CASL also supports: "fields": "status"
    
    // 5. Priority is NOT in the JSON
    print("\n5. Priority is internal to CASL, not in JSON")
    
    // 6. Inverted false is not encoded
    print("\n6. Only inverted: true is included in JSON")
    
    // MARK: - Common Mistakes to Avoid
    
    print("\n=== Common Format Mistakes ===")
    
    // ❌ WRONG: Our original format
    let wrongFormat = """
    {
        "action": "read",
        "subject": "Article",
        "priority": 10,
        "inverted": false
    }
    """
    
    // ✅ CORRECT: CASL format
    let correctFormat = """
    {
        "action": "read",
        "subject": "Article"
    }
    """
    
    print("Wrong format includes 'priority' and 'inverted: false'")
    print("Correct format omits these fields")
    
    // MARK: - Practical PantryKit Example
    
    let pantryPermissionsJSON = """
    [
        {
            "action": "read",
            "subject": "Household"
        },
        {
            "action": ["create", "read", "update", "delete"],
            "subject": "Recipe",
            "conditions": {
                "householdId": "${currentHouseholdId}"
            }
        },
        {
            "action": "manage",
            "subject": "Household",
            "conditions": {
                "ownerId": "${userId}"
            }
        },
        {
            "action": ["invite", "remove"],
            "subject": "HouseholdMember",
            "conditions": {
                "householdId": "${currentHouseholdId}",
                "role": "admin"
            }
        },
        {
            "action": "delete",
            "subject": ["Recipe", "ShoppingList"],
            "inverted": true,
            "conditions": {
                "protected": true
            },
            "reason": "Protected items cannot be deleted"
        }
    ]
    """
    
    let pantryAbility = try PureAbility.from(jsonString: pantryPermissionsJSON)
    
    print("\n=== Pantry App Permissions ===")
    print("Can read any household:", pantryAbility.can("read", "Household"))
    print("Can create recipes in current household:", pantryAbility.can("create", "Recipe"))
    print("Can manage owned households:", pantryAbility.can("manage", "Household"))
    print("Cannot delete protected recipes:", pantryAbility.cannot("delete", "Recipe"))
}