#!/bin/bash

# This script validates and fixes Bluetooth permission issues in the app bundle

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Checking and fixing Bluetooth permissions...${NC}"

# Verify Info.plist exists
if [ ! -f "NothingX/Info.plist" ]; then
    echo -e "${RED}Error: Info.plist not found at NothingX/Info.plist${NC}"
    exit 1
fi

echo -e "${GREEN}Info.plist found at NothingX/Info.plist${NC}"

# Verify entitlements file exists
if [ ! -f "NothingX/NothingX.entitlements" ]; then
    echo -e "${RED}Error: Entitlements file not found at NothingX/NothingX.entitlements${NC}"
    exit 1
fi

echo -e "${GREEN}Entitlements file found at NothingX/NothingX.entitlements${NC}"

# Validate the Info.plist XML
echo -e "${YELLOW}Validating Info.plist...${NC}"
plutil -lint NothingX/Info.plist
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Info.plist has invalid format${NC}"
    exit 1
fi

echo -e "${GREEN}Info.plist is valid${NC}"

# Check for required Bluetooth keys
echo -e "${YELLOW}Checking for required Bluetooth keys in Info.plist...${NC}"
required_keys=(
    "NSBluetoothAlwaysUsageDescription" 
    "NSBluetoothPeripheralUsageDescription"
    "NSBluetoothUsageDescription"
    "NSBluetoothServicesUsageDescription"
)

for key in "${required_keys[@]}"; do
    value=$(plutil -extract $key xml1 -o - NothingX/Info.plist 2>/dev/null)
    if [[ $value == *"not found"* ]] || [[ -z "$value" ]]; then
        echo -e "${RED}Warning: $key not found in Info.plist${NC}"
        echo -e "${YELLOW}Adding $key to Info.plist...${NC}"
        plutil -replace $key -string "NothingX needs Bluetooth access to connect to and control your Nothing earbuds." NothingX/Info.plist
    else
        echo -e "${GREEN}Found $key in Info.plist${NC}"
    fi
done

# Check entitlements
echo -e "${YELLOW}Checking for Bluetooth entitlement...${NC}"
ent_value=$(plutil -extract "com.apple.security.device.bluetooth" xml1 -o - NothingX/NothingX.entitlements 2>/dev/null)
if [[ $ent_value == *"not found"* ]] || [[ -z "$ent_value" ]]; then
    echo -e "${RED}Warning: Bluetooth entitlement not found${NC}"
    echo -e "${YELLOW}Adding Bluetooth entitlement...${NC}"
    plutil -replace "com.apple.security.device.bluetooth" -bool true NothingX/NothingX.entitlements
else
    echo -e "${GREEN}Found Bluetooth entitlement${NC}"
fi

echo -e "${GREEN}Bluetooth permissions check complete.${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Clean your project (Cmd+Shift+K)"
echo "2. Build and run again" 