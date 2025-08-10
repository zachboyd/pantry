#!/bin/bash

# Script to make Apollo generated types public
# This fixes the issue where generated types are internal by default

set -e

# Change to the project root directory
cd "$(dirname "$0")/.."

echo "🔧 Making Apollo generated types public..."

# Find all generated Swift files and make them public
find Sources/JeevesKit/GraphQL/Generated -name "*.swift" -type f | while read -r file; do
    echo "Processing: $file"
    
    # Make classes, structs, and enums public
    sed -i '' -E 's/^([[:space:]]*)class ([[:alnum:]_]+)/\1public class \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)struct ([[:alnum:]_]+)/\1public struct \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)enum ([[:alnum:]_]+)/\1public enum \2/g' "$file"
    
    # Make static properties and methods public
    sed -i '' -E 's/^([[:space:]]*)static let ([[:alnum:]_]+)/\1public static let \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)static var ([[:alnum:]_]+)/\1public static var \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)static func ([[:alnum:]_]+)/\1public static func \2/g' "$file"
    
    # Make typealias public
    sed -i '' -E 's/^([[:space:]]*)typealias ([[:alnum:]_]+)/\1public typealias \2/g' "$file"
    
    # Make instance properties and methods public
    sed -i '' -E 's/^([[:space:]]*)let ([[:alnum:]_]+)/\1public let \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)var ([[:alnum:]_]+)/\1public var \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)private\(set\) var ([[:alnum:]_]+)/\1public private(set) var \2/g' "$file"
    sed -i '' -E 's/^([[:space:]]*)init\(/\1public init(/g' "$file"
    
    # Make protocols public
    sed -i '' -E 's/^([[:space:]]*)protocol ([[:alnum:]_]+)/\1public protocol \2/g' "$file"
    
    # Make functions public (but be careful not to duplicate 'public')
    sed -i '' -E 's/^([[:space:]]*)func ([[:alnum:]_]+)/\1public func \2/g' "$file"
    
    # Clean up any double 'public' keywords
    sed -i '' -E 's/public public/public/g' "$file"
done

echo "✅ Apollo types made public!"