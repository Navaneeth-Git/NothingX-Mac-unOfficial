//
//  ContentView.swift
//  NothingX
//
//  Created by Navaneeth on 5/31/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @State private var showBatteryPopover = false
    
    var body: some View {
        if let permissionError = viewModel.bluetoothManager.permissionError {
            // Permission error view
            ErrorView(title: "Bluetooth Permission Error", message: permissionError)
        } else if viewModel.connectedDevice != nil {
            // Connected device view - modern all-in-one UI
            ConnectedDeviceView()
                .environmentObject(viewModel)
        } else {
            // Not connected view
            NotConnectedView()
                .environmentObject(viewModel)
        }
    }
}

// MARK: - Connected Device View
struct ConnectedDeviceView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @State private var showControls = true
    @State private var currentEQPreset: EqualizerPreset = .balanced
    @State private var currentANCMode: ANCMode = .off
    @State private var showingGestureSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with battery info and device name
            headerView
            
            // Main content area
            ScrollView {
                VStack(spacing: 24) {
                    // Device visual
                    deviceVisualView
                    
                    // Quick controls
                    if showControls {
                        quickControlsView
                    }
                    
                    // Control sections
                    Group {
                        noiseCancellingSection
                        
                        equalizerSection
                        
                        gesturesSection
                        
                        otherSettingsSection
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .background(Color(.windowBackgroundColor))
        .frame(minWidth: 800, minHeight: 700)
        .onAppear {
            currentEQPreset = viewModel.equalizerPreset
            currentANCMode = viewModel.ancMode
        }
        .sheet(isPresented: $showingGestureSettings) {
            GestureSettingsView()
                .environmentObject(viewModel)
                .frame(width: 600, height: 500)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.connectedDevice?.name ?? "Nothing Earbuds")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Firmware: \(viewModel.firmwareVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Battery levels
            HStack(spacing: 16) {
                batteryIndicator(level: viewModel.batteryLevels.left, label: "L")
                batteryIndicator(level: viewModel.batteryLevels.right, label: "R")
                batteryIndicator(level: viewModel.batteryLevels.case, label: "Case")
            }
            
            Button(action: { viewModel.disconnect() }) {
                Text("Disconnect")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
        }
        .padding()
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.2)),
            alignment: .bottom
        )
    }
    
    // MARK: - Device Visual View
    private var deviceVisualView: some View {
        HStack(spacing: 24) {
            VStack {
                Image(systemName: "earbuds.case.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.primary)
                
                Text("Connected")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            
            VStack(spacing: 16) {
                Button(action: { viewModel.findMyEarbuds() }) {
                    Label("Find My Earbuds", systemImage: "location")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                
                if let error = viewModel.bluetoothManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Quick Controls View
    private var quickControlsView: some View {
        HStack(spacing: 12) {
            quickControlButton(title: "ANC Off", isActive: viewModel.ancMode == .off) {
                viewModel.setANCMode(.off)
                currentANCMode = .off
            }
            
            quickControlButton(title: "ANC High", isActive: viewModel.ancMode == .high) {
                viewModel.setANCMode(.high)
                currentANCMode = .high
            }
            
            quickControlButton(title: "Transparency", isActive: viewModel.ancMode == .transparency) {
                viewModel.setANCMode(.transparency)
                currentANCMode = .transparency
            }
            
            Divider()
                .frame(height: 30)
            
            quickControlButton(title: "Balanced EQ", isActive: viewModel.equalizerPreset == .balanced) {
                viewModel.setEqualizerPreset(.balanced)
                currentEQPreset = .balanced
            }
            
            quickControlButton(title: "More Bass", isActive: viewModel.equalizerPreset == .moreBass) {
                viewModel.setEqualizerPreset(.moreBass)
                currentEQPreset = .moreBass
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal)
    }
    
    // MARK: - Noise Cancelling Section
    private var noiseCancellingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Noise Control", systemImage: "ear")
            
            Picker("Noise Control Mode", selection: $currentANCMode) {
                ForEach(ANCMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: currentANCMode) { newValue in
                viewModel.setANCMode(newValue)
            }
            
            Toggle("Personalized ANC", isOn: $viewModel.isPersonalizedANCEnabled)
                .toggleStyle(.switch)
                .onChange(of: viewModel.isPersonalizedANCEnabled) { newValue in
                    viewModel.togglePersonalizedANC(newValue)
                }
            
            if viewModel.isPersonalizedANCEnabled {
                Button("Run Ear Tip Fit Test") {
                    viewModel.runEarTipFitTest()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.fitTestStatus == .inProgress)
                
                if viewModel.fitTestStatus == .completed {
                    Text("Fit Test Result: \(viewModel.fitTestResult.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Equalizer Section
    private var equalizerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Equalizer", systemImage: "slider.horizontal.3")
            
            Picker("Equalizer Preset", selection: $currentEQPreset) {
                ForEach(EqualizerPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: currentEQPreset) { newValue in
                viewModel.setEqualizerPreset(newValue)
            }
            
            if currentEQPreset == .custom {
                VStack(spacing: 16) {
                    HStack {
                        Text("Bass")
                            .font(.caption)
                        Spacer()
                        Text("Treble")
                            .font(.caption)
                    }
                    
                    HStack(spacing: 8) {
                        ForEach(0..<6) { index in
                            EqualizerSlider(value: $viewModel.customEqualizerSettings[index])
                        }
                    }
                    
                    Button("Apply Custom EQ") {
                        viewModel.setCustomEqualizerValues(viewModel.customEqualizerSettings)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            
            Toggle("Advanced EQ", isOn: $viewModel.isAdvancedEQEnabled)
                .toggleStyle(.switch)
                .onChange(of: viewModel.isAdvancedEQEnabled) { newValue in
                    viewModel.toggleAdvancedEQ(newValue)
                }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Gestures Section
    private var gesturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Gesture Controls", systemImage: "hand.tap")
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Left Earbud")
                        .font(.headline)
                    
                    ForEach(GestureType.allCases) { gestureType in
                        HStack {
                            Text(gestureType.rawValue)
                                .frame(width: 100, alignment: .leading)
                            Text(":")
                            Text(viewModel.leftEarbudGestures[gestureType]?.rawValue ?? "None")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Right Earbud")
                        .font(.headline)
                    
                    ForEach(GestureType.allCases) { gestureType in
                        HStack {
                            Text(gestureType.rawValue)
                                .frame(width: 100, alignment: .leading)
                            Text(":")
                            Text(viewModel.rightEarbudGestures[gestureType]?.rawValue ?? "None")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button("Configure Gestures") {
                showingGestureSettings = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Other Settings Section
    private var otherSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Additional Settings", systemImage: "gear")
            
            Toggle("In-Ear Detection", isOn: $viewModel.isInEarDetectionEnabled)
                .toggleStyle(.switch)
                .onChange(of: viewModel.isInEarDetectionEnabled) { newValue in
                    viewModel.toggleInEarDetection(newValue)
                }
            
            Toggle("Low Latency Mode", isOn: $viewModel.isLowLatencyModeEnabled)
                .toggleStyle(.switch)
                .onChange(of: viewModel.isLowLatencyModeEnabled) { newValue in
                    viewModel.toggleLowLatencyMode(newValue)
                }
            
            Text("Device Model: \(viewModel.connectedDevice?.type.displayName ?? "Unknown")")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Firmware: \(viewModel.firmwareVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            Spacer()
        }
    }
    
    private func batteryIndicator(level: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            batteryIcon(level: level)
            
            Text("\(level)%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func batteryIcon(level: Int) -> some View {
        let systemName: String
        
        if level <= 10 {
            systemName = "battery.0"
        } else if level <= 25 {
            systemName = "battery.25"
        } else if level <= 50 {
            systemName = "battery.50"
        } else if level <= 75 {
            systemName = "battery.75"
        } else {
            systemName = "battery.100"
        }
        
        let color: Color = level <= 20 ? .red : (level <= 40 ? .yellow : .green)
        
        return Image(systemName: systemName)
            .foregroundColor(color)
    }
    
    private func quickControlButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.accentColor : Color.gray.opacity(0.2))
                )
                .foregroundColor(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gesture Settings Sheet
struct GestureSettingsView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEarbud: EarbudSide = .left
    @State private var temporaryGestures: [EarbudSide: [GestureType: GestureAction]] = [
        .left: [:],
        .right: [:]
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Configure Gesture Controls")
                    .font(.headline)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            // Earbud selector
            Picker("Earbud", selection: $selectedEarbud) {
                Text("Left Earbud").tag(EarbudSide.left)
                Text("Right Earbud").tag(EarbudSide.right)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Gesture configuration
            List {
                ForEach(GestureType.allCases) { gestureType in
                    HStack {
                        Text(gestureType.rawValue)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { 
                                getCurrentGestureAction(for: gestureType) 
                            },
                            set: { newAction in
                                setGestureAction(for: gestureType, action: newAction)
                            }
                        )) {
                            ForEach(GestureAction.allCases) { action in
                                Text(action.rawValue).tag(action)
                            }
                        }
                        .frame(width: 200)
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(maxHeight: .infinity)
            
            // Save button
            HStack {
                Button("Reset to Default") {
                    resetToDefaults()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Apply Changes") {
                    applyChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            // Initialize temporary gestures with current values
            temporaryGestures[.left] = viewModel.leftEarbudGestures
            temporaryGestures[.right] = viewModel.rightEarbudGestures
        }
    }
    
    private func getCurrentGestureAction(for gestureType: GestureType) -> GestureAction {
        let gestures = selectedEarbud == .left ? temporaryGestures[.left] : temporaryGestures[.right]
        return gestures?[gestureType] ?? .none
    }
    
    private func setGestureAction(for gestureType: GestureType, action: GestureAction) {
        if temporaryGestures[selectedEarbud] == nil {
            temporaryGestures[selectedEarbud] = [:]
        }
        temporaryGestures[selectedEarbud]?[gestureType] = action
    }
    
    private func resetToDefaults() {
        let defaults: [GestureType: GestureAction] = [
            .singleTap: .playPause,
            .doubleTap: .nextTrack,
            .tripleTap: .previousTrack,
            .holdTap: .toggleANC
        ]
        
        temporaryGestures[selectedEarbud] = defaults
    }
    
    private func applyChanges() {
        if let leftGestures = temporaryGestures[.left] {
            for (gestureType, action) in leftGestures {
                viewModel.setGestureAction(for: .left, gestureType: gestureType, action: action)
            }
        }
        
        if let rightGestures = temporaryGestures[.right] {
            for (gestureType, action) in rightGestures {
                viewModel.setGestureAction(for: .right, gestureType: gestureType, action: action)
            }
        }
    }
}

// MARK: - Equalizer Slider
struct EqualizerSlider: View {
    @Binding var value: Float
    
    var body: some View {
        VStack {
            Text("\(Int(value))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Slider(value: $value, in: -10...10, step: 1)
                .rotationEffect(.degrees(-90))
                .frame(width: 80, height: 24)
                .padding(.top, 50)
            
            Text("")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Not Connected View
struct NotConnectedView: View {
    @EnvironmentObject private var viewModel: EarbudViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "earbuds.case.fill")
                .font(.system(size: 120))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Connect your Nothing Earbuds")
                .font(.title)
                .fontWeight(.medium)
            
            Text("Control your earbuds, adjust settings, and customize your experience")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if viewModel.bluetoothState == .poweredOff {
                Text("Bluetooth is turned off")
                    .foregroundColor(.red)
                    .padding(.top, 10)
                
                Button("Open Bluetooth Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: { viewModel.startScanning() }) {
                    Text("Scan for Devices")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
                
                if let error = viewModel.bluetoothManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }
            }
            
            Spacer()
            
            Text("NothingX v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 600, minHeight: 600)
        .padding()
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.isScanning },
            set: { if !$0 { viewModel.stopScanning() } }
        )) {
            DeviceScannerView()
                .environmentObject(viewModel)
                .frame(width: 400, height: 300)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundColor(.yellow)
            
            Text(title)
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(message)
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
