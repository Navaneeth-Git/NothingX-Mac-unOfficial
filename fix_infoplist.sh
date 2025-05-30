#!/bin/bash

# This script adds a custom Xcode configuration file that explicitly sets the Info.plist path

# Create a .xcconfig file with the Info.plist path
cat > NothingX.xcconfig << EOL
// Custom build settings
INFOPLIST_FILE = NothingX/Info.plist
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
INFOPLIST_KEY_NSBluetoothPeripheralUsageDescription = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
INFOPLIST_KEY_NSBluetoothUsageDescription = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
EOL

echo "Created NothingX.xcconfig with explicit Info.plist path"
echo "To use this configuration file:"
echo "1. Open your project in Xcode"
echo "2. Select the NothingX project in the navigator"
echo "3. Select the NothingX target"
echo "4. Go to Build Settings tab"
echo "5. Click '+' at the top and select 'Add User-Defined Setting'"
echo "6. Set the name to INFOPLIST_FILE and the value to \${SRCROOT}/NothingX/Info.plist"
echo "7. Clean and rebuild your project" 