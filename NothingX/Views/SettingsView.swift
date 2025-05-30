import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("startAtLogin") private var startAtLogin = false
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("autoConnect") private var autoConnect = true
    @State private var isCheckingForUpdates = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Settings
                appSettingsCard
                
                // Connection Settings
                connectionSettingsCard
                
                // About
                aboutCard
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - App Settings Card
    private var appSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("App Settings", systemImage: "gearshape")
                .font(.headline)
            
            Divider()
            
            VStack(spacing: 16) {
                // App theme
                HStack {
                    Text("App Theme")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Picker("", selection: $appTheme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Start at login
                Toggle("Start at Login", isOn: $startAtLogin)
                    .toggleStyle(.switch)
                
                // Show in menu bar
                Toggle("Show in Menu Bar", isOn: $showInMenuBar)
                    .toggleStyle(.switch)
                
                // Check for updates
                HStack {
                    Text("Check for Updates")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button(action: {
                        isCheckingForUpdates = true
                        // Simulate checking for updates
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isCheckingForUpdates = false
                        }
                    }) {
                        if isCheckingForUpdates {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Check Now")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCheckingForUpdates)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Connection Settings Card
    private var connectionSettingsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Connection Settings", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            
            Divider()
            
            VStack(spacing: 16) {
                // Auto-connect
                Toggle("Auto-connect to Last Device", isOn: $autoConnect)
                    .toggleStyle(.switch)
                
                // Reset all connections
                Button("Reset All Connections") {
                    // Implement connection reset
                    viewModel.disconnect()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - About Card
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("About", systemImage: "info.circle")
                .font(.headline)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("NothingX")
                    .font(.title3)
                    .bold()
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("A native macOS app for controlling Nothing earbuds")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                
                Text("Based on the ear-web project")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("Visit ear-web project", destination: URL(string: "https://github.com/radiance-project/ear-web")!)
                    .font(.caption)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

#Preview {
    SettingsView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
} 