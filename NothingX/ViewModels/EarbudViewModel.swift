import Foundation
import CoreBluetooth
import Combine
import SwiftUI

class EarbudViewModel: ObservableObject {
    // Services
    let bluetoothManager: BluetoothManager
    private let earbudManager: EarbudManager
    
    // Cancellables for subscriptions
    var cancellables = Set<AnyCancellable>()
    
    // Published properties for UI
    @Published var isScanning = false
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectedDevice: BluetoothDevice?
    @Published var batteryLevels: (left: Int, right: Int, case: Int) = (0, 0, 0)
    
    // Bluetooth state
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var showError = false
    
    // Equalizer settings
    @Published var equalizerPreset: EqualizerPreset = .balanced
    @Published var customEqualizerSettings: [Float] = [0, 0, 0, 0, 0, 0]
    @Published var isAdvancedEQEnabled = false
    
    // ANC settings
    @Published var ancMode: ANCMode = .off
    @Published var isPersonalizedANCEnabled = false
    
    // Other settings
    @Published var isInEarDetectionEnabled = true
    @Published var isLowLatencyModeEnabled = false
    @Published var firmwareVersion: String = "Unknown"
    
    // Gesture mappings (default values)
    @Published var leftEarbudGestures: [GestureType: GestureAction] = [
        .singleTap: .playPause,
        .doubleTap: .nextTrack,
        .tripleTap: .previousTrack,
        .holdTap: .toggleANC
    ]
    
    @Published var rightEarbudGestures: [GestureType: GestureAction] = [
        .singleTap: .playPause,
        .doubleTap: .nextTrack,
        .tripleTap: .previousTrack,
        .holdTap: .toggleANC
    ]
    
    // Status for fit test
    @Published var fitTestStatus: FitTestStatus = .notStarted
    @Published var fitTestResult: EarTipFitResult = .unsupported
    
    init(bluetoothManager: BluetoothManager, earbudManager: EarbudManager) {
        self.bluetoothManager = bluetoothManager
        self.earbudManager = earbudManager
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func startScanning() {
        if bluetoothState != .poweredOn {
            showErrorMessage("Bluetooth is not available. Please enable Bluetooth.")
            return
        }
        
        bluetoothManager.startScanning()
    }
    
    func stopScanning() {
        bluetoothManager.stopScanning()
    }
    
    func connect(to device: BluetoothDevice) {
        connectionState = .connecting
        bluetoothManager.connect(to: device)
    }
    
    func disconnect() {
        connectionState = .disconnecting
        bluetoothManager.disconnect()
    }
    
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        earbudManager.setEqualizerPreset(preset)
    }
    
    func setCustomEqualizerValues(_ values: [Float]) {
        earbudManager.setCustomEqualizerValues(values)
    }
    
    func setANCMode(_ mode: ANCMode) {
        earbudManager.setANCMode(mode)
    }
    
    func toggleAdvancedEQ(_ enabled: Bool) {
        earbudManager.toggleAdvancedEQ(enabled)
    }
    
    func toggleInEarDetection(_ enabled: Bool) {
        earbudManager.toggleInEarDetection(enabled)
    }
    
    func toggleLowLatencyMode(_ enabled: Bool) {
        earbudManager.toggleLowLatencyMode(enabled)
    }
    
    func togglePersonalizedANC(_ enabled: Bool) {
        earbudManager.togglePersonalizedANC(enabled)
    }
    
    func runEarTipFitTest() {
        guard let device = connectedDevice, device.type.supportsPersonalizedANC else {
            fitTestResult = .unsupported
            return
        }
        
        fitTestStatus = .inProgress
        
        earbudManager.runEarTipFitTest { [weak self] result in
            DispatchQueue.main.async {
                self?.fitTestResult = result
                self?.fitTestStatus = .completed
            }
        }
    }
    
    func setGestureAction(for earbud: EarbudSide, gestureType: GestureType, action: GestureAction) {
        if earbud == .left {
            leftEarbudGestures[gestureType] = action
        } else {
            rightEarbudGestures[gestureType] = action
        }
        
        // TODO: Implement actual communication with earbuds
    }
    
    func findMyEarbuds() {
        earbudManager.findMyEarbuds()
    }
    
    // MARK: - Error Handling
    
    func showErrorMessage(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.errorMessage = message
            self.showError = true
        }
    }
    
    func dismissError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind bluetooth manager properties
        bluetoothManager.$isScanning
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isScanning = value
            }
            .store(in: &cancellables)
        
        bluetoothManager.$discoveredDevices
            .receive(on: RunLoop.main)
            .assign(to: \.discoveredDevices, on: self)
            .store(in: &cancellables)
        
        bluetoothManager.$connectedDevice
            .receive(on: RunLoop.main)
            .sink { [weak self] device in
                guard let self = self else { return }
                self.connectedDevice = device
                
                if device != nil {
                    self.connectionState = .connected
                } else if self.connectionState != .disconnecting {
                    self.connectionState = .disconnected
                }
            }
            .store(in: &cancellables)
        
        bluetoothManager.$batteryLevels
            .receive(on: RunLoop.main)
            .assign(to: \.batteryLevels, on: self)
            .store(in: &cancellables)
            
        bluetoothManager.$bluetoothState
            .receive(on: RunLoop.main)
            .assign(to: \.bluetoothState, on: self)
            .store(in: &cancellables)
        
        // Bind earbud manager properties
        earbudManager.$equalizerPreset
            .receive(on: RunLoop.main)
            .assign(to: \.equalizerPreset, on: self)
            .store(in: &cancellables)
        
        earbudManager.$customEqualizerSettings
            .receive(on: RunLoop.main)
            .assign(to: \.customEqualizerSettings, on: self)
            .store(in: &cancellables)
        
        earbudManager.$isAdvancedEQEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.isAdvancedEQEnabled, on: self)
            .store(in: &cancellables)
        
        earbudManager.$ancMode
            .receive(on: RunLoop.main)
            .assign(to: \.ancMode, on: self)
            .store(in: &cancellables)
        
        earbudManager.$isPersonalizedANCEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.isPersonalizedANCEnabled, on: self)
            .store(in: &cancellables)
        
        earbudManager.$isInEarDetectionEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.isInEarDetectionEnabled, on: self)
            .store(in: &cancellables)
        
        earbudManager.$isLowLatencyModeEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.isLowLatencyModeEnabled, on: self)
            .store(in: &cancellables)
        
        earbudManager.$firmwareVersion
            .receive(on: RunLoop.main)
            .assign(to: \.firmwareVersion, on: self)
            .store(in: &cancellables)
    }
}

// MARK: - Additional Types

enum EarbudSide {
    case left
    case right
}

enum GestureType: String, CaseIterable, Identifiable {
    case singleTap = "Single Tap"
    case doubleTap = "Double Tap"
    case tripleTap = "Triple Tap"
    case holdTap = "Hold"
    
    var id: String { self.rawValue }
}

enum FitTestStatus {
    case notStarted
    case inProgress
    case completed
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case disconnecting
} 
