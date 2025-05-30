#!/bin/bash

# This script forces Xcode to use the new Info.plist at the project root

echo "Setting up direct Info.plist reference..."

# Create a simple xcconfig file that overrides the Info.plist path
cat > NothingXDirectSettings.xcconfig << EOL
// Force Info.plist path to root
INFOPLIST_FILE = Info.plist
EOL

echo "Created NothingXDirectSettings.xcconfig with explicit root Info.plist path"

# Create a direct build setting script for Xcode
cat > set_infoplist_path.rb << EOL
#!/usr/bin/ruby

require 'xcodeproj'

project_path = 'NothingX.xcodeproj'

begin
  # Open the Xcode project
  project = Xcodeproj::Project.open(project_path)
  
  # Find the main target
  target = project.targets.find { |t| t.name == 'NothingX' }
  
  if target.nil?
    puts "Error: Target 'NothingX' not found"
    exit 1
  end
  
  # Go through each build configuration and set INFOPLIST_FILE
  target.build_configurations.each do |config|
    puts "Setting INFOPLIST_FILE for configuration: \#{config.name}"
    config.build_settings['INFOPLIST_FILE'] = 'Info.plist'
  end
  
  # Save the project
  project.save
  
  puts "Successfully updated INFOPLIST_FILE setting to 'Info.plist'"
rescue => e
  puts "Error: \#{e.message}"
  exit 1
end
EOL

# Make the script executable
chmod +x set_infoplist_path.rb

echo "Created set_infoplist_path.rb script"

# Try to install xcodeproj gem if it's not available
if ! gem list -i xcodeproj > /dev/null 2>&1; then
  echo "Installing xcodeproj gem..."
  sudo gem install xcodeproj
fi

# Run the ruby script
if ruby set_infoplist_path.rb; then
  echo "Xcode project successfully updated to use root Info.plist"
else
  echo "Failed to update Xcode project. You'll need to manually set INFOPLIST_FILE to 'Info.plist' in your build settings."
fi

echo ""
echo "IMPORTANT: Now you need to:"
echo "1. Open your Xcode project"
echo "2. Select the NothingX target"
echo "3. Go to Build Settings"
echo "4. Search for 'Info.plist'"
echo "5. Set 'Info.plist File' to 'Info.plist' (relative to project root)"
echo "6. Clean and rebuild your project"
echo ""

# Validate the Info.plist
echo "Validating root Info.plist..."
plutil -lint Info.plist
if [ $? -ne 0 ]; then
    echo "Error: Info.plist has invalid format"
    exit 1
fi

echo "Info.plist is valid"
echo "Done! Your app should now properly include Bluetooth permissions." 