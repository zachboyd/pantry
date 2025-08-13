@preconcurrency import Apollo
import CASLSwift
import Foundation
import Observation

// MARK: - Permission Types

/// Represents a CASL permission rule from the backend
public struct PermissionRule: Codable, Sendable {
    public let action: StringOrArray
    public let subject: StringOrArray?
    public let fields: StringOrArray?
    public let conditions: [String: AnyCodable]?
    public let inverted: Bool?
    public let reason: String?
}

/// User permissions from the backend
public struct UserPermissions: Codable, Sendable {
    public let rules: [PermissionRule]
    public let version: String?
}

// MARK: - Jeeves-Specific Types

/// Actions available in the Jeeves application
public enum JeevesAction: String, CaseIterable {
    case create
    case read
    case update
    case delete
    case manage // Special action meaning all actions
}

/// Subjects (resources) in the Jeeves application
public enum JeevesSubject: String {
    case user = "User"
    case household = "Household"
    case householdMember = "HouseholdMember"
    case message = "Message"
    case pantry = "Pantry"
    case all // Special subject meaning all subjects
}

/// Jeeves-specific Ability class
/// Using typealias since we can't inherit from Ability directly
public typealias JeevesAbility = Ability<JeevesAction, JeevesSubject>

// MARK: - Permission Service Protocol

@MainActor
public protocol PermissionServiceProtocol: AnyObject {
    /// The current user's ability instance
    var currentAbility: JeevesAbility? { get }

    /// Extract permissions from Apollo-cached User data
    func extractPermissionsFromUser(_ user: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser?) async -> UserPermissions?

    /// Build ability from user permissions
    func buildAbility(from permissions: UserPermissions) async -> JeevesAbility

    /// Subscribe to user permission updates from Apollo cache
    func subscribeToUserPermissions(apolloClient: ApolloClient) async

    /// Clear cached permissions
    func clearPermissions() async
}

// MARK: - Permission Service Implementation

@MainActor
@Observable
public final class PermissionService: PermissionServiceProtocol {
    // MARK: - Properties

    public private(set) var currentAbility: JeevesAbility?
    private var permissionWatcher: GraphQLQueryWatcher<JeevesGraphQL.GetCurrentUserQuery>?
    private let logger = Logger.permissions

    // MARK: - Initialization

    public init() {
        logger.info("PermissionService initialized")
    }

    // No deinit needed as permissionWatcher will be cleaned up when cleared

    // MARK: - Public Methods

    /// Extract permissions from Apollo-cached User data
    public func extractPermissionsFromUser(_ user: JeevesGraphQL.GetCurrentUserQuery.Data.CurrentUser?) async -> UserPermissions? {
        guard let user = user else {
            logger.debug("No user data available for permission extraction")
            return nil
        }

        // Extract permissions from the JSON field
        guard let permissionsJSON = user.permissions,
              !permissionsJSON.value.isEmpty,
              permissionsJSON.value != "null"
        else {
            // Return basic fallback permissions
            let rules = [
                PermissionRule(
                    action: .single("read"),
                    subject: .single("User"),
                    fields: nil,
                    conditions: ["id": AnyCodable(user.id)],
                    inverted: nil,
                    reason: nil
                ),
                PermissionRule(
                    action: .single("update"),
                    subject: .single("User"),
                    fields: nil,
                    conditions: ["id": AnyCodable(user.id)],
                    inverted: nil,
                    reason: nil
                ),
            ]
            return UserPermissions(rules: rules, version: "1.0.0")
        }

        // Decode JSON data to array
        let permissionsArray: [[String: Any]]

        // First, try to parse the JSON string
        if let jsonData = permissionsJSON.value.data(using: .utf8) {
            do {
                let decoded = try JSONSerialization.jsonObject(with: jsonData)

                // Check if it's an array
                if let array = decoded as? [[String: Any]] {
                    // Dictionary format array
                    permissionsArray = array
                } else if let compactArray = decoded as? [[Any]] {
                    // Compact format array (array of arrays)
                    var rules: [[String: Any]] = []

                    for compactRule in compactArray {
                        // Convert compact format to dictionary format
                        var ruleDict: [String: Any] = [:]

                        // Index 0: action (required)
                        if compactRule.count > 0 {
                            ruleDict["action"] = compactRule[0]
                        }

                        // Index 1: subject (optional)
                        if compactRule.count > 1 {
                            ruleDict["subject"] = compactRule[1]
                        }

                        // Index 2: conditions (optional)
                        if compactRule.count > 2 {
                            ruleDict["conditions"] = compactRule[2]
                        }

                        // Index 3: fields (optional)
                        if compactRule.count > 3 {
                            ruleDict["fields"] = compactRule[3]
                        }

                        // Index 4: inverted (optional)
                        if compactRule.count > 4 {
                            ruleDict["inverted"] = compactRule[4]
                        }

                        // Index 5: reason (optional)
                        if compactRule.count > 5 {
                            ruleDict["reason"] = compactRule[5]
                        }

                        rules.append(ruleDict)
                    }

                    permissionsArray = rules
                } else if let nsArray = decoded as? NSArray {
                    // Handle NSArray case - could be compact format or dictionary format

                    // Check if it's compact format (array of arrays) or dictionary format
                    if let firstItem = nsArray.firstObject {
                        if firstItem is [Any] || firstItem is NSArray {
                            // Compact format - convert to dictionary format
                            var rules: [[String: Any]] = []

                            for item in nsArray {
                                if let compactRule = item as? [Any] {
                                    // Convert compact format to dictionary format
                                    var ruleDict: [String: Any] = [:]

                                    // Index 0: action (required)
                                    if compactRule.count > 0 {
                                        ruleDict["action"] = compactRule[0]
                                    }

                                    // Index 1: subject (optional)
                                    if compactRule.count > 1 {
                                        ruleDict["subject"] = compactRule[1]
                                    }

                                    // Index 2: conditions (optional)
                                    if compactRule.count > 2 {
                                        ruleDict["conditions"] = compactRule[2]
                                    }

                                    // Index 3: fields (optional)
                                    if compactRule.count > 3 {
                                        ruleDict["fields"] = compactRule[3]
                                    }

                                    // Index 4: inverted (optional)
                                    if compactRule.count > 4 {
                                        ruleDict["inverted"] = compactRule[4]
                                    }

                                    // Index 5: reason (optional)
                                    if compactRule.count > 5 {
                                        ruleDict["reason"] = compactRule[5]
                                    }

                                    rules.append(ruleDict)
                                }
                            }

                            permissionsArray = rules
                        } else {
                            // Dictionary format
                            var rules: [[String: Any]] = []
                            for item in nsArray {
                                if let dict = item as? [String: Any] {
                                    rules.append(dict)
                                } else if let dict = item as? NSDictionary {
                                    rules.append(dict as! [String: Any])
                                }
                            }
                            permissionsArray = rules
                        }
                    } else {
                        // Empty array
                        permissionsArray = []
                    }
                } else if let dict = decoded as? [String: Any] {
                    // Maybe it's wrapped in an object?
                    if let rules = dict["rules"] as? [[String: Any]] {
                        permissionsArray = rules
                    } else {
                        logger.error("Failed to parse permissions: dictionary doesn't contain 'rules' array")
                        return nil
                    }
                } else {
                    logger.error("Failed to parse permissions: unexpected format")
                    return nil
                }
            } catch {
                logger.error("Failed to parse permissions JSON: \(error)")
                return nil
            }
        } else {
            logger.error("Failed to convert permissions string to UTF-8 data")
            return nil
        }

        logger.debug("Processing \(permissionsArray.count) permission rules from GraphQL")

        var rules: [PermissionRule] = []

        for permissionDict in permissionsArray {
            // Extract action (required)
            guard let actionValue = permissionDict["action"] else {
                continue
            }

            let action: StringOrArray
            if let actionString = actionValue as? String {
                action = .single(actionString)
            } else if let actionArray = actionValue as? [String] {
                action = .array(actionArray)
            } else {
                continue
            }

            // Extract subject (optional)
            let subject: StringOrArray?
            if let subjectValue = permissionDict["subject"] {
                if let subjectString = subjectValue as? String {
                    subject = .single(subjectString)
                } else if let subjectArray = subjectValue as? [String] {
                    subject = .array(subjectArray)
                } else {
                    subject = nil
                }
            } else {
                subject = nil
            }

            // Extract fields (optional)
            let fields: StringOrArray?
            if let fieldsValue = permissionDict["fields"] {
                if let fieldsString = fieldsValue as? String {
                    fields = .single(fieldsString)
                } else if let fieldsArray = fieldsValue as? [String] {
                    fields = .array(fieldsArray)
                } else {
                    fields = nil
                }
            } else {
                fields = nil
            }

            // Extract conditions (optional)
            let conditions: [String: AnyCodable]?
            if let conditionsDict = permissionDict["conditions"] as? [String: Any] {
                conditions = conditionsDict.mapValues { AnyCodable($0) }
            } else {
                conditions = nil
            }

            // Extract inverted (optional)
            let inverted = permissionDict["inverted"] as? Bool

            // Extract reason (optional)
            let reason = permissionDict["reason"] as? String

            let rule = PermissionRule(
                action: action,
                subject: subject,
                fields: fields,
                conditions: conditions,
                inverted: inverted,
                reason: reason
            )

            rules.append(rule)
        }

        logger.debug("\(rules.count) rules successfully processed")
        return UserPermissions(rules: rules, version: "1.0.0")
    }

    /// Build ability from user permissions
    public func buildAbility(from permissions: UserPermissions) async -> JeevesAbility {
        logger.info("🏗️ Building ability from \(permissions.rules.count) permission rules")
        let builder = AbilityBuilder<JeevesAction, JeevesSubject>()

        // Process each rule individually to validate action/subject types
        for (index, rule) in permissions.rules.enumerated() {
            logger.info("📜 Processing rule \(index + 1):")

            // Validate and convert actions from strings to JeevesAction enum
            let actionStrings = rule.action.values
            logger.info("  Actions: \(actionStrings)")
            let validActions = actionStrings.compactMap { JeevesAction(rawValue: $0) }

            if validActions.isEmpty {
                logger.warning("⚠️ Skipping rule with invalid actions: \(actionStrings)")
                continue
            }

            // Validate and convert subjects from strings to JeevesSubject enum (if present)
            let subjectStrings = rule.subject?.values ?? ["all"]
            logger.info("  Subjects: \(subjectStrings)")
            let validSubjects = subjectStrings.compactMap { subjectString -> JeevesSubject? in
                if subjectString == "all" {
                    return .all
                } else {
                    return JeevesSubject(rawValue: subjectString)
                }
            }

            if validSubjects.isEmpty {
                logger.warning("⚠️ Skipping rule with invalid subjects: \(subjectStrings)")
                continue
            }

            // Convert conditions to proper format
            let conditions: [String: Any]? = rule.conditions?.mapValues { $0.value }
            if let conditions = conditions {
                logger.info("  Conditions: \(conditions)")
            }
            logger.info("  Inverted: \(rule.inverted ?? false)")

            // Add rules for each valid action/subject combination
            for action in validActions {
                for subject in validSubjects {
                    if rule.inverted == true {
                        if let conditions = conditions {
                            builder.cannot(action, subject, conditions)
                            logger.info("  ➡️ Added CANNOT rule: \(action.rawValue) on \(subject.rawValue) with conditions")
                        } else {
                            builder.cannot(action, subject)
                            logger.info("  ➡️ Added CANNOT rule: \(action.rawValue) on \(subject.rawValue)")
                        }
                    } else {
                        if let conditions = conditions {
                            builder.can(action, subject, conditions)
                            logger.info("  ➡️ Added CAN rule: \(action.rawValue) on \(subject.rawValue) with conditions")
                        } else {
                            builder.can(action, subject)
                            logger.info("  ➡️ Added CAN rule: \(action.rawValue) on \(subject.rawValue)")
                        }
                    }
                }
            }
        }

        let ability = await builder.build()
        logger.info("✅ Built ability with typed enum validation")

        // Log a summary of all rules
        logger.info("📊 Rule Summary:")
        var rulesBySubject: [String: [(action: String, hasConditions: Bool, inverted: Bool)]] = [:]

        for rule in permissions.rules {
            let actions = rule.action.values
            let subjects = rule.subject?.values ?? ["all"]
            let hasConditions = rule.conditions != nil
            let inverted = rule.inverted ?? false

            for subject in subjects {
                for action in actions {
                    if rulesBySubject[subject] == nil {
                        rulesBySubject[subject] = []
                    }
                    rulesBySubject[subject]?.append((action: action, hasConditions: hasConditions, inverted: inverted))
                }
            }
        }

        for (subject, rules) in rulesBySubject.sorted(by: { $0.key < $1.key }) {
            logger.info("  Subject '\(subject)':")
            for rule in rules {
                let ruleType = rule.inverted ? "CANNOT" : "CAN"
                let conditionInfo = rule.hasConditions ? " (with conditions)" : ""
                logger.info("    - \(ruleType) \(rule.action)\(conditionInfo)")
            }
        }

        // Store ability for debugging
        currentAbility = ability

        return ability
    }

    /// Subscribe to user permission updates from Apollo cache
    public func subscribeToUserPermissions(apolloClient: ApolloClient) async {
        // Cancel any existing watcher
        permissionWatcher?.cancel()

        // Create a new watcher for the current user query
        permissionWatcher = apolloClient.watch(
            query: JeevesGraphQL.GetCurrentUserQuery(),
            cachePolicy: .returnCacheDataAndFetch
        ) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }

                switch result {
                case let .success(graphQLResult):
                    if let user = graphQLResult.data?.currentUser {
                        self.logger.info("🔄 Received user permission update for user: \(user.id)")
                        // Extract and build new ability
                        if let permissions = await self.extractPermissionsFromUser(user) {
                            self.currentAbility = await self.buildAbility(from: permissions)
                            self.logger.info("✅ Current ability updated successfully")
                        } else {
                            self.logger.warning("⚠️ Failed to extract permissions from user")
                        }
                    } else {
                        self.logger.warning("⚠️ No current user data in GraphQL result")
                    }

                case let .failure(error):
                    self.logger.error("Failed to watch user permissions: \(error)")
                }
            }
        }
    }

    /// Clear cached permissions
    public func clearPermissions() async {
        currentAbility = nil
        permissionWatcher?.cancel()
        permissionWatcher = nil
    }
}

// MARK: - Convenience Extensions

public extension JeevesAbility {
    /// Debug helper to log available rules
    private func logAvailableRules(for action: JeevesAction, subject: String) {
        Logger.permissions.info("    🔎 Looking for rules matching: action=\(action.rawValue), subject=\(subject)")
        Logger.permissions.info("    📚 Note: Rules are evaluated internally by CASL library")
    }

    /// Check if user can perform an action on a household
    func canManageHousehold(_ householdId: String) -> Bool {
        // Create a subject with the specific household ID
        let household = StringIdentifiableSubject<EmptyProperties>(
            id: householdId,
            properties: EmptyProperties(),
            subjectType: "Household"
        )

        let result = canSync(.manage, household) ?? false
        Logger.permissions.info("🔍 canManageHousehold(\(householdId)): \(result)")
        return result
    }

    /// Check if user can read a household
    func canReadHousehold(_ householdId: String) -> Bool {
        // Create a subject with the specific household ID
        let household = StringIdentifiableSubject<EmptyProperties>(
            id: householdId,
            properties: EmptyProperties(),
            subjectType: "Household"
        )

        let result = canSync(.read, household) ?? false
        Logger.permissions.info("🔍 canReadHousehold(\(householdId)): \(result)")
        return result
    }

    /// Check if user can update a household
    func canUpdateHousehold(_ householdId: String) -> Bool {
        // Create a subject with the specific household ID
        let household = StringIdentifiableSubject<EmptyProperties>(
            id: householdId,
            properties: EmptyProperties(),
            subjectType: "Household"
        )

        let result = canSync(.update, household) ?? false
        Logger.permissions.info("🔍 canUpdateHousehold(\(householdId)): \(result)")
        return result
    }

    /// Check if user can delete a household
    func canDeleteHousehold(_ householdId: String) -> Bool {
        // Create a subject with the specific household ID
        let household = StringIdentifiableSubject<EmptyProperties>(
            id: householdId,
            properties: EmptyProperties(),
            subjectType: "Household"
        )

        let result = canSync(.delete, household) ?? false
        Logger.permissions.info("🔍 canDeleteHousehold(\(householdId)): \(result)")
        return result
    }

    /// Check if user can create a new household member
    func canCreateHouseholdMember(in householdId: String) -> Bool {
        Logger.permissions.info("🔍 Evaluating canCreateHouseholdMember(in: \(householdId))")

        // Check if they can create HouseholdMember
        // Note: If they have "manage" permission on HouseholdMember, that includes "create"
        let memberSubject = SubjectFactory.simple(
            type: "HouseholdMember",
            properties: ["household_id": householdId]
        )

        Logger.permissions.info("  📋 Checking create permission on HouseholdMember with household_id: \(householdId)")
        logAvailableRules(for: .create, subject: "HouseholdMember")
        Logger.permissions.info("    🔍 Evaluating against subject with properties: [household_id: \(householdId)]")
        Logger.permissions.info("    📝 Note: 'manage' permission includes 'create' in CASL")

        let result = canSync(.create, memberSubject) ?? false
        Logger.permissions.info("  🔍 Result: canCreate = \(result)")
        return result
    }

    /// Check if user can manage a specific household member
    func canManageHouseholdMember(in householdId: String, role: String) -> Bool {
        // Check if they have permission to manage HouseholdMember
        // Using SimpleSubject to access properties dictionary properly
        let memberSubject = SubjectFactory.simple(
            type: "HouseholdMember",
            properties: [
                "household_id": householdId,
                "role": role,
            ]
        )

        let result = canSync(.manage, memberSubject) ?? false
        Logger.permissions.info("🔍 canManageHouseholdMember(in: \(householdId), role: \(role)): \(result)")
        return result
    }

    /// Legacy method for backward compatibility
    @available(*, deprecated, renamed: "canCreateHouseholdMember(in:)")
    func canManageMembers(in householdId: String) -> Bool {
        return canCreateHouseholdMember(in: householdId)
    }
}

// MARK: - Supporting Types for Permission Checks

// Empty properties for subjects that only need an ID
struct EmptyProperties: Sendable {}

// Properties for household member subjects
struct MemberProperties: Sendable {
    let household_id: String
}
