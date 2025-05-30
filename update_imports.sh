#!/bin/bash

# Revert the EarbudTypes imports
echo "Reverting imports..."
FILES=(
  "NothingX/Models/BluetoothManager.swift"
  "NothingX/Models/BluetoothDevice.swift"
  "NothingX/Models/EarbudManager.swift"
  "NothingX/ViewModels/EarbudViewModel.swift"
  "NothingX/ContentView.swift"
  "NothingX/Views/DeviceScannerView.swift"
)

for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    sed -i '' 's/import EarbudTypes//g' "$file"
    echo "Removed EarbudTypes import from $file"
  fi
done

echo "Done reverting imports" 