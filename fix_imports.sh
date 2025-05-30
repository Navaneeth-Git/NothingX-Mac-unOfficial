#!/bin/bash

# Function to update import statements in Swift files
update_imports() {
  local file=$1
  
  # Check if import for EarbudTypes already exists
  if ! grep -q "import.*EarbudTypes" "$file"; then
    # Add import statement after Foundation import
    sed -i '' 's/import Foundation/import Foundation\nimport EarbudTypes/' "$file"
    echo "Added EarbudTypes import to $file"
  fi
}

# Update all Swift files with imports
echo "Updating imports..."
update_imports "NothingX/Models/BluetoothManager.swift"
update_imports "NothingX/Models/BluetoothDevice.swift"
update_imports "NothingX/Models/EarbudManager.swift"
update_imports "NothingX/ViewModels/EarbudViewModel.swift"
update_imports "NothingX/ContentView.swift"
update_imports "NothingX/Views/DeviceScannerView.swift"

# Remove duplicate enum definitions
echo "Removing duplicate enum definitions..."

# Remove ANCMode, EqualizerPreset, and GestureAction definitions from EarbudManager.swift
sed -i '' '/^enum ANCMode/,/^}/d' "NothingX/Models/EarbudManager.swift"
sed -i '' '/^enum EqualizerPreset/,/^}/d' "NothingX/Models/EarbudManager.swift"
sed -i '' '/^enum GestureAction/,/^}/d' "NothingX/Models/EarbudManager.swift"

# Remove all enum definitions from BluetoothManager.swift
sed -i '' '/^enum ANCMode/,/^}/d' "NothingX/Models/BluetoothManager.swift"
sed -i '' '/^enum EqualizerPreset/,/^}/d' "NothingX/Models/BluetoothManager.swift"
sed -i '' '/^enum GestureType/,/^}/d' "NothingX/Models/BluetoothManager.swift"
sed -i '' '/^enum GestureAction/,/^}/d' "NothingX/Models/BluetoothManager.swift"
sed -i '' '/^enum EarbudSide/,/^}/d' "NothingX/Models/BluetoothManager.swift"
sed -i '' '/^enum EarTipFitResult/,/^}/d' "NothingX/Models/BluetoothManager.swift"

# Remove duplicate DeviceType and EarTipFitResult from BluetoothDevice.swift
sed -i '' '/^enum DeviceType/,/^}/d' "NothingX/Models/BluetoothDevice.swift"
sed -i '' '/^enum EarTipFitResult/,/^}/d' "NothingX/Models/BluetoothDevice.swift"

echo "Done fixing imports and removing duplicate definitions" 