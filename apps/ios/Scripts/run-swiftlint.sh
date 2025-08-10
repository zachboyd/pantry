#!/bin/bash

# Run SwiftLint for Jeeves iOS App
# This script runs SwiftLint with the project's configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to the iOS app directory
cd "$(dirname "$0")/.." || exit 1

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo -e "${RED}Error: SwiftLint is not installed${NC}"
    echo "Install SwiftLint using one of these methods:"
    echo "  brew install swiftlint"
    echo "  mint install realm/SwiftLint"
    exit 1
fi

echo -e "${GREEN}Running SwiftLint...${NC}"

# Run SwiftLint
if [ "$1" = "--fix" ] || [ "$1" = "autocorrect" ]; then
    echo -e "${YELLOW}Running SwiftLint with autocorrect...${NC}"
    swiftlint autocorrect
else
    swiftlint
fi

# Check the exit code
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SwiftLint completed successfully${NC}"
else
    echo -e "${RED}✗ SwiftLint found issues${NC}"
    exit 1
fi