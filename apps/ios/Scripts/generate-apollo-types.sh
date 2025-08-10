#!/bin/bash

# Apollo GraphQL Code Generation Script
# This script generates Swift types from GraphQL schema and operations

set -e  # Exit on any error

# Change to the project root directory
cd "$(dirname "$0")/.."

echo "🚀 Starting Apollo GraphQL code generation..."

# Check if apollo-ios-cli exists
if [ ! -f "./apollo-ios-cli" ]; then
    echo "❌ Apollo CLI not found. Installing..."
    swift package --allow-writing-to-package-directory --allow-network-connections all apollo-cli-install
fi

# Ensure GraphQL operations directory exists
mkdir -p Sources/JeevesKit/GraphQL/Operations

# Check if schema file exists
if [ ! -f "schema.gql" ]; then
    echo "❌ GraphQL schema not found. Copying from backend..."
    if [ -f "../packages/api/src/generated/schema.gql" ]; then
        cp "../packages/api/src/generated/schema.gql" "schema.gql"
        echo "✅ Schema copied successfully"
    else
        echo "❌ Backend schema not found at ../packages/api/src/generated/schema.gql"
        echo "Please ensure the backend schema is generated or update the path"
        exit 1
    fi
fi

# Check if operations exist
OPERATIONS_COUNT=$(find Sources/JeevesKit/GraphQL/Operations -name "*.graphql" | wc -l)
if [ "$OPERATIONS_COUNT" -eq 0 ]; then
    echo "⚠️  No GraphQL operations found. Creating basic operations..."
    # The operations file should already exist from the setup
fi

# Generate Apollo types
echo "🔄 Generating Apollo types..."
./apollo-ios-cli generate

# Check if generation was successful
if [ -d "Sources/JeevesKit/GraphQL/Generated" ]; then
    echo "✅ Apollo types generated successfully!"
    echo "📁 Generated files in: Sources/JeevesKit/GraphQL/Generated"
    
    # Make all generated types public
    echo "🔧 Making Apollo generated types public..."
    ./Scripts/make-apollo-types-public.sh
else
    echo "❌ Apollo type generation failed"
    exit 1
fi

echo "🎉 Apollo GraphQL setup complete!"