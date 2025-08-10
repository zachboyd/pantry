#!/bin/bash

# Build script for Jeeves iOS app
# Usage: ./Scripts/build.sh [debug|release]

set -e

# Configuration
SCHEME="Jeeves"
CONFIGURATION=${1:-debug}
WORKSPACE="Jeeves.xcworkspace"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🏗️  Building Jeeves iOS app...${NC}"
echo -e "Configuration: ${CONFIGURATION}"
echo -e "Workspace: ${WORKSPACE}"
echo ""

# Check if workspace exists
if [ ! -d "$WORKSPACE" ]; then
    echo -e "${RED}❌ Workspace not found: $WORKSPACE${NC}"
    exit 1
fi

# Build for iOS Simulator
echo -e "${YELLOW}📱 Building for iOS Simulator...${NC}"
xcodebuild -workspace "$WORKSPACE" \
           -scheme "$SCHEME" \
           -configuration "$CONFIGURATION" \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build completed successfully!${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

# Run tests
echo -e "${YELLOW}🧪 Running tests...${NC}"
swift test

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
else
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Build and test completed successfully!${NC}"