#!/bin/bash

# Define paths
APP_DIR="NothingX"
INFO_PLIST_PATH="$APP_DIR/Info.plist"
TARGET_NAME="NothingX"

# Check if Info.plist exists
if [ ! -f "$INFO_PLIST_PATH" ]; then
    echo "Error: Info.plist not found at $INFO_PLIST_PATH"
    exit 1
fi

# Create a temporary project.pbxproj file
cat > add_infoplist.rb << EOL
#!/usr/bin/ruby

# Path to your Xcode project
project_path = "NothingX.xcodeproj/project.pbxproj"

# Read the project file
project_content = File.read(project_path)

# Check if INFOPLIST_FILE is already set
if project_content.include?("INFOPLIST_FILE")
  puts "INFOPLIST_FILE already exists in project.pbxproj"
else
  # Find the build configuration lists for the target
  target_section = project_content.scan(/\/\* $TARGET_NAME \*\/ = \{.*?buildConfigurationList = ([0-9A-F]+);.*?\};/m)
  
  if target_section.empty?
    puts "Could not find target $TARGET_NAME in project.pbxproj"
    exit 1
  end
  
  # Get the build configuration list ID
  config_list_id = target_section[0][0]
  
  # Find the actual build configurations
  config_list_section = project_content.scan(/#{config_list_id} \/\* Build configuration list for PBXNativeTarget "#{TARGET_NAME}" \*\/ = \{.*?buildConfigurations = \((.*?)\);.*?\};/m)
  
  if config_list_section.empty?
    puts "Could not find build configuration list in project.pbxproj"
    exit 1
  end
  
  # Get the configuration IDs
  config_ids = config_list_section[0][0].scan(/([0-9A-F]+) \/\* (Debug|Release) \*\//)
  
  # Add INFOPLIST_FILE to each configuration
  config_ids.each do |config_id, config_name|
    # Find the configuration section
    config_section = project_content.scan(/#{config_id} \/\* #{config_name} \*\/ = \{.*?buildSettings = \{(.*?)\};.*?\};/m)
    
    if config_section.empty?
      puts "Could not find build configuration #{config_name} in project.pbxproj"
      next
    end
    
    # Add INFOPLIST_FILE setting
    updated_section = config_section[0][0] + "\n\t\t\t\tINFOPLIST_FILE = \"#{INFO_PLIST_PATH}\";"
    
    # Replace the original section with the updated one
    project_content.gsub!(/#{config_id} \/\* #{config_name} \*\/ = \{.*?buildSettings = \{(.*?)\};.*?\};/m, 
                          "#{config_id} /* #{config_name} */ = {\n\t\t\tbuildSettings = {#{updated_section}\n\t\t\t};\n\t\t\tname = #{config_name};\n\t\t};")
  end
  
  # Write the updated project file
  File.write(project_path, project_content)
  puts "Added INFOPLIST_FILE = \"#{INFO_PLIST_PATH}\" to project.pbxproj"
end
EOL

# Make the script executable
chmod +x add_infoplist.rb

# Run the script
ruby add_infoplist.rb

echo "Script completed. Now rebuild your project." 