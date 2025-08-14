#!/bin/bash

# Read JSON from stdin
json=$(cat)

# Extract file_path from JSON
file_path=$(echo "$json" | grep -o '"file_path":"[^"]*"' | sed 's/"file_path":"\([^"]*\)"/\1/')

# Check if file_path exists and is a Swift file in the iOS app
if [[ -n "$file_path" && "$file_path" == */apps/ios/*.swift ]]; then
    swiftformat --swiftversion 6.1 "$file_path"
fi