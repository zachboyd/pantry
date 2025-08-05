@preconcurrency import Apollo
import Foundation
import os

/// Interceptor that automatically trims whitespace from string values in GraphQL mutations
final class StringTrimmingInterceptor: ApolloInterceptor, @unchecked Sendable {
    private static let logger = Logger.graphql
    let id: String = UUID().uuidString
    
    /// Configuration for trimming behavior
    private let configuration: TrimmingConfiguration
    
    init(configuration: TrimmingConfiguration = .default) {
        self.configuration = configuration
    }
    
    func interceptAsync<Operation>(
        chain: any RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) where Operation: GraphQLOperation {
        
        // Only process mutations if enabled
        guard configuration.enabledForMutations && Operation.operationType == .mutation else {
            chain.proceedAsync(request: request, response: response, 
                             interceptor: self, completion: completion)
            return
        }
        
        // Process variables for string trimming
        if let variables = request.operation.__variables {
            do {
                // Note: Apollo iOS currently doesn't provide a way to modify request variables
                // in interceptors. This code demonstrates the trimming logic that would be
                // applied if Apollo supported variable modification.
                // For now, trimming should be done at the service layer.
                let _ = try trimVariables(from: variables)
                
                if configuration.enableLogging {
                    Self.logger.debug("🔤 Would trim variables for mutation (trimming at service layer instead)")
                }
            } catch {
                Self.logger.error("❌ Failed to process variables for trimming: \(error)")
            }
        }
        
        // Continue with the original request
        chain.proceedAsync(request: request, response: response,
                         interceptor: self, completion: completion)
    }
    
    private func trimVariables(from variables: [AnyHashable: Any]) throws -> [AnyHashable: Any] {
        var trimmed: [AnyHashable: Any] = [:]
        
        for (key, value) in variables {
            if let stringKey = key as? String {
                trimmed[key] = try trimValue(value, fieldName: stringKey)
            } else {
                trimmed[key] = value
            }
        }
        
        return trimmed
    }
    
    private func trimValue(_ value: Any, fieldName: String) throws -> Any {
        switch value {
        case let string as String:
            // Check if field should be excluded from trimming
            guard !configuration.excludedFields.contains(fieldName.lowercased()) else {
                return string
            }
            
            // Check max length to prevent processing huge strings
            guard string.count <= configuration.maxStringLength else {
                return string
            }
            
            let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if configuration.enableLogging && string != trimmedString {
                Self.logger.debug("🔤 Trimmed '\(fieldName)': '\(string.prefix(20))...' → '\(trimmedString.prefix(20))...'")
            }
            
            return trimmedString
            
        case let dict as [String: Any]:
            return try trimVariables(from: dict)
            
        case let array as [Any]:
            return try array.map { try trimValue($0, fieldName: fieldName) }
            
        default:
            return value
        }
    }
}

/// Configuration for string trimming behavior
public struct TrimmingConfiguration: Sendable {
    /// Enable trimming for GraphQL mutations
    public let enabledForMutations: Bool
    
    /// Enable trimming for GraphQL queries (typically not needed)
    public let enabledForQueries: Bool
    
    /// Field names that should not be trimmed (e.g., formatted text, code snippets)
    public let excludedFields: Set<String>
    
    /// Maximum string length to process (prevents processing huge strings)
    public let maxStringLength: Int
    
    /// Enable debug logging of trimming operations
    public let enableLogging: Bool
    
    public init(
        enabledForMutations: Bool = true,
        enabledForQueries: Bool = false,
        excludedFields: Set<String> = [],
        maxStringLength: Int = 10000,
        enableLogging: Bool = false
    ) {
        self.enabledForMutations = enabledForMutations
        self.enabledForQueries = enabledForQueries
        self.excludedFields = excludedFields
        self.maxStringLength = maxStringLength
        self.enableLogging = enableLogging
    }
    
    /// Default configuration with common excluded fields
    public static let `default` = TrimmingConfiguration(
        excludedFields: ["code_snippet", "formatted_text", "raw_content", "markdown", "html"]
    )
}