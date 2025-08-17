// @generated
// This file was automatically generated and can be edited to
// provide custom configuration for a generated GraphQL schema.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

import ApolloAPI

enum SchemaConfiguration: ApolloAPI.SchemaConfiguration {
    public static func cacheKeyInfo(for type: ApolloAPI.Object, object: ApolloAPI.ObjectData) -> CacheKeyInfo? {
        // Configure cache key resolution to enable proper cache normalization
        // This ensures mutations, subscriptions, and queries for the same entity
        // all update the same cache entry, allowing watchers to detect changes

        switch type {
        case JeevesGraphQL.Objects.User:
            // Normalize User objects by their ID
            if let id = object["id"] as? String {
                return CacheKeyInfo(id: id)
            }

        case JeevesGraphQL.Objects.Household:
            // Normalize Household objects by their ID
            if let id = object["id"] as? String {
                return CacheKeyInfo(id: id)
            }

        case JeevesGraphQL.Objects.HouseholdMember:
            // Normalize HouseholdMember objects by their ID
            if let id = object["id"] as? String {
                return CacheKeyInfo(id: id)
            }

        default:
            // For any other types without IDs, return nil to use default cache keys
            break
        }

        return nil
    }
}
