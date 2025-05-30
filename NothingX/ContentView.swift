//
//  ContentView.swift
//  NothingX
//
//  Created by Navaneeth on 5/31/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @State private var selectedTab: Tab = .dashboard
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(Tab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("NothingX")
            .toolbar {
                ToolbarItem {
                    if viewModel.connectedDevice != nil {
                        Button(action: { viewModel.disconnect() }) {
                            Label("Disconnect", systemImage: "xmark.circle")
                        }
                    } else {
                        Button(action: {
                            if viewModel.bluetoothState == .poweredOn {
                                viewModel.startScanning()
                            } else {
                                viewModel.showErrorMessage("Bluetooth is not available")
                            }
                        }) {
                            Label("Connect", systemImage: "plus.circle")
                        }
                    }
                }
            }
        } detail: {
            // Detail view based on selected tab
            tabView
                .navigationTitle(selectedTab.title)
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.isScanning },
            set: { if !$0 { viewModel.stopScanning() } }
        )) {
            DeviceScannerView()
                .environmentObject(viewModel)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Error"),
                message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK")) {
                    viewModel.dismissError()
                }
            )
        }
        .overlay {
            if viewModel.connectionState == .connecting {
                connectingOverlay
            }
        }
    }
    
    private var connectingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Connecting...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.windowBackgroundColor).opacity(0.9))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var tabView: some View {
        if let permissionError = viewModel.bluetoothManager.permissionError {
            // Permission error view
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.yellow)
                
                Text("Bluetooth Permission Error")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text(permissionError)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Please make sure your Info.plist contains all required Bluetooth permission keys.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("View Documentation") {
                    if let url = URL(string: "https://developer.apple.com/documentation/corebluetooth") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        } else if let device = viewModel.connectedDevice {
            switch selectedTab {
            case .dashboard:
                DashboardView(device: device)
                    .environmentObject(viewModel)
            case .equalizer:
                EqualizerView()
                    .environmentObject(viewModel)
            case .anc:
                ANCView()
                    .environmentObject(viewModel)
            case .gestures:
                GesturesView()
                    .environmentObject(viewModel)
            case .settings:
                SettingsView()
                    .environmentObject(viewModel)
            }
        } else {
            // Not connected view
            VStack(spacing: 20) {
                Image(systemName: "ear.and.waveform")
                    .font(.system(size: 72))
                    .foregroundColor(.secondary)
                
                Text("No earbuds connected")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                if viewModel.bluetoothState == .poweredOff {
                    Text("Bluetooth is turned off")
                        .foregroundColor(.secondary)
                    
                    Button("Open Bluetooth Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Connect to Device") {
                        viewModel.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.windowBackgroundColor))
        }
    }
}

// MARK: - Tab Enum
enum Tab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case equalizer = "Equalizer"
    case anc = "Noise Control"
    case gestures = "Gestures"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var title: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .equalizer: return "slider.horizontal.3"
        case .anc: return "ear"
        case .gestures: return "hand.tap"
        case .settings: return "gear"
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .environmentObject(EarbudViewModel(
            bluetoothManager: BluetoothManager(),
            earbudManager: EarbudManager(bluetoothManager: BluetoothManager())
        ))
}
