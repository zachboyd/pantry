// @generated
// This file was automatically generated and can be edited to
// provide custom configuration for a generated GraphQL schema.
//
// Any changes to this file will not be overwritten by future
// code generation execution.

import ApolloAPI

public enum SchemaConfiguration: ApolloAPI.SchemaConfiguration {
    public static func cacheKeyInfo(for type: ApolloAPI.Object, object: ApolloAPI.ObjectData) -> CacheKeyInfo? {
        // Configure cache key resolution for proper normalization
        // This ensures mutations and queries for the same object update the same cache entry

        // Most GraphQL types use 'id' as their unique identifier
        // This enables Apollo to properly merge data from different operations (queries/mutations)
        if let id = object["id"] as? String {
            return CacheKeyInfo(id: id, uniqueKeyGroup: type.typename)
        }

        // Fallback to default behavior for types without an id field
        return nil
    }
}
