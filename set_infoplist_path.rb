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
