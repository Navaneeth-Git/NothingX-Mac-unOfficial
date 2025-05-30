//
//  NothingXApp.swift
//  NothingX
//
//  Created by Navaneeth on 5/31/25.
//

import SwiftUI
import CoreBluetooth

@main
struct NothingXApp: App {
    // App-wide managers
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var earbudManager: EarbudManager
    
    // App-wide view model
    @StateObject private var viewModel: EarbudViewModel
    
    // Alert state
    @State private var showBluetoothAlert = false
    
    init() {
        // Debug Info.plist entries to verify they're loaded correctly
        if let infoDictionary = Bundle.main.infoDictionary {
            // Log available permission keys to validate
            if let bluetoothDescription = infoDictionary["NSBluetoothAlwaysUsageDescription"] as? String {
                print("Found NSBluetoothAlwaysUsageDescription: \(bluetoothDescription)")
            } else {
                print("WARNING: NSBluetoothAlwaysUsageDescription not found in Info.plist")
            }
            
            if let bluetoothServicesDescription = infoDictionary["NSBluetoothServicesUsageDescription"] as? String {
                print("Found NSBluetoothServicesUsageDescription: \(bluetoothServicesDescription)")
            } else {
                print("WARNING: NSBluetoothServicesUsageDescription not found in Info.plist")
            }
            
            // Validate other required Info.plist entries
            let requiredKeys = ["NSBluetoothPeripheralUsageDescription", "NSBluetoothUsageDescription"]
            for key in requiredKeys {
                if infoDictionary[key] == nil {
                    print("WARNING: \(key) not found in Info.plist")
                }
            }
            
            // Register Bluetooth usage descriptions programmatically as a backup
            var mutableInfoDictionary = infoDictionary
            mutableInfoDictionary["NSBluetoothAlwaysUsageDescription"] = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
            mutableInfoDictionary["NSBluetoothPeripheralUsageDescription"] = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
            mutableInfoDictionary["NSBluetoothUsageDescription"] = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
            mutableInfoDictionary["NSBluetoothServicesUsageDescription"] = "NothingX needs Bluetooth access to connect to and control your Nothing earbuds."
        }
        
        // Initialize managers and view model
        let bluetoothManager = BluetoothManager()
        let earbudManager = EarbudManager(bluetoothManager: bluetoothManager)
        
        self._earbudManager = StateObject(wrappedValue: earbudManager)
        self._bluetoothManager = StateObject(wrappedValue: bluetoothManager)
        self._viewModel = StateObject(wrappedValue: EarbudViewModel(
            bluetoothManager: bluetoothManager,
            earbudManager: earbudManager
        ))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    checkBluetoothPermissions()
                }
                .alert(isPresented: $showBluetoothAlert) {
                    Alert(
                        title: Text("Bluetooth Required"),
                        message: Text("NothingX needs Bluetooth to connect to your earbuds. Please enable Bluetooth in Settings."),
                        primaryButton: .default(Text("Open Settings"), action: openSettings),
                        secondaryButton: .cancel()
                    )
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
    
    // Check Bluetooth permissions and status
    private func checkBluetoothPermissions() {
        // Monitor Bluetooth state changes
        bluetoothManager.$bluetoothState
            .sink { state in
                if state == .poweredOff || state == .unauthorized {
                    self.showBluetoothAlert = true
                }
            }
            .store(in: &viewModel.cancellables)
    }
    
    // Open system settings
    private func openSettings() {
        guard let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}
