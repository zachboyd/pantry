import Foundation

// MARK: - String Trimming Extensions

public extension String {
    /// Trim whitespace and newlines with performance optimization
    /// - Returns: Trimmed string, or self if no trimming needed
    func trimmed() -> String {
        // Performance optimization: only create new string if needed
        guard !isEmpty && (hasPrefix(" ") || hasSuffix(" ") || 
              contains("\n") || contains("\r") || contains("\t")) else {
            return self
        }
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if string needs trimming (useful for validation)
    var needsTrimming: Bool {
        !isEmpty && (hasPrefix(" ") || hasSuffix(" ") || 
         contains("\n") || contains("\r") || contains("\t"))
    }
}

public extension Optional where Wrapped == String {
    /// Trim optional strings, returning nil for empty results
    /// - Returns: Trimmed string or nil if empty after trimming
    func trimmed() -> String? {
        guard let value = self?.trimmed(), !value.isEmpty else {
            return nil
        }
        return value
    }
    
    /// Trim optional strings, preserving empty strings
    /// - Returns: Trimmed string or nil if original was nil
    func trimmedPreservingEmpty() -> String? {
        guard let value = self else { return nil }
        return value.trimmed()
    }
}