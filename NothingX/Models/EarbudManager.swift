import Foundation
import Combine

class EarbudManager: ObservableObject {
    // BluetoothManager dependency
    private let bluetoothManager: BluetoothManager
    
    // Published properties for the UI
    @Published var ancMode: ANCMode = .off
    @Published var equalizerPreset: EqualizerPreset = .balanced
    @Published var customEqualizerSettings: [Float] = [0, 0, 0, 0, 0, 0] // 6-band EQ
    @Published var isAdvancedEQEnabled = false
    @Published var isInEarDetectionEnabled = true
    @Published var isLowLatencyModeEnabled = false
    @Published var isPersonalizedANCEnabled = false
    
    // Other device properties
    @Published var firmwareVersion: String = "Unknown"
    
    // Cancellable subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Subscribe to changes in the connected device
        bluetoothManager.$connectedDevice
            .sink { [weak self] device in
                if device != nil {
                    self?.loadDeviceSettings()
                } else {
                    self?.resetSettings()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public methods
    
    // Set ANC mode
    func setANCMode(_ mode: ANCMode) {
        guard let device = bluetoothManager.connectedDevice, 
              device.type.supportsANC else {
            return
        }
        
        // TODO: Implement actual BLE communication to set ANC mode
        self.ancMode = mode
    }
    
    // Set equalizer preset
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to set equalizer preset
        self.equalizerPreset = preset
        
        // Reset custom EQ settings when selecting a preset
        if preset != .custom {
            self.customEqualizerSettings = preset.defaultValues
        }
    }
    
    // Set custom equalizer values
    func setCustomEqualizerValues(_ values: [Float]) {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to set custom equalizer values
        self.customEqualizerSettings = values
        self.equalizerPreset = .custom
    }
    
    // Toggle Advanced EQ
    func toggleAdvancedEQ(_ enabled: Bool) {
        guard let device = bluetoothManager.connectedDevice,
              device.type.supportsAdvancedEQ else {
            return
        }
        
        // TODO: Implement actual BLE communication to toggle advanced EQ
        self.isAdvancedEQEnabled = enabled
    }
    
    // Toggle In-Ear Detection
    func toggleInEarDetection(_ enabled: Bool) {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to toggle in-ear detection
        self.isInEarDetectionEnabled = enabled
    }
    
    // Toggle Low Latency Mode
    func toggleLowLatencyMode(_ enabled: Bool) {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to toggle low latency mode
        self.isLowLatencyModeEnabled = enabled
    }
    
    // Toggle Personalized ANC
    func togglePersonalizedANC(_ enabled: Bool) {
        guard let device = bluetoothManager.connectedDevice,
              device.type.supportsPersonalizedANC else {
            return
        }
        
        // TODO: Implement actual BLE communication to toggle personalized ANC
        self.isPersonalizedANCEnabled = enabled
    }
    
    // Run ear tip fit test
    func runEarTipFitTest(completion: @escaping (EarTipFitResult) -> Void) {
        guard let device = bluetoothManager.connectedDevice,
              device.type.supportsPersonalizedANC else {
            completion(.unsupported)
            return
        }
        
        // TODO: Implement actual BLE communication to run ear tip fit test
        // For now, just simulate a test result after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let result = EarTipFitResult.good
            completion(result)
        }
    }
    
    // Find my earbuds function
    func findMyEarbuds() {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to trigger find my earbuds feature
        print("Finding earbuds...")
    }
    
    // MARK: - Private methods
    
    // Load device settings from the connected earbuds
    private func loadDeviceSettings() {
        guard let device = bluetoothManager.connectedDevice else {
            return
        }
        
        // TODO: Implement actual BLE communication to load device settings
        // For now, just set some default values based on the device type
        
        // Reset settings to defaults for the device type
        ancMode = device.type.supportsANC ? .off : .unsupported
        equalizerPreset = .balanced
        customEqualizerSettings = EqualizerPreset.balanced.defaultValues
        isAdvancedEQEnabled = false
        isInEarDetectionEnabled = true
        isLowLatencyModeEnabled = false
        isPersonalizedANCEnabled = false
        firmwareVersion = "1.0.0" // Placeholder
    }
    
    // Reset settings when disconnected
    private func resetSettings() {
        ancMode = .unsupported
        equalizerPreset = .balanced
        customEqualizerSettings = EqualizerPreset.balanced.defaultValues
        isAdvancedEQEnabled = false
        isInEarDetectionEnabled = true
        isLowLatencyModeEnabled = false
        isPersonalizedANCEnabled = false
        firmwareVersion = "Unknown"
    }
}

// MARK: - Enums

enum ANCMode: String, CaseIterable, Identifiable {
    case high = "High"
    case mid = "Mid"
    case low = "Low"
    case transparency = "Transparency"
    case off = "Off"
    case unsupported = "Unsupported"
    
    var id: String { self.rawValue }
    
    var isActive: Bool {
        switch self {
        case .high, .mid, .low:
            return true
        case .transparency, .off, .unsupported:
            return false
        }
    }
}

enum EqualizerPreset: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case moreVoice = "More Voice"
    case moreBass = "More Bass"
    case moreTreble = "More Treble"
    case custom = "Custom"
    
    var id: String { self.rawValue }
    
    var defaultValues: [Float] {
        switch self {
        case .balanced:
            return [0, 0, 0, 0, 0, 0]
        case .moreVoice:
            return [0, 0, 2, 2, 0, 0]
        case .moreBass:
            return [3, 2, 0, 0, 0, 0]
        case .moreTreble:
            return [0, 0, 0, 0, 2, 3]
        case .custom:
            return [0, 0, 0, 0, 0, 0]
        }
    }
}

enum EarTipFitResult {
    case good
    case fair
    case poor
    case unsupported
}

enum GestureAction: String, CaseIterable, Identifiable {
    case playPause = "Play/Pause"
    case nextTrack = "Next Track"
    case previousTrack = "Previous Track"
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"
    case toggleANC = "Toggle ANC"
    case voiceAssistant = "Voice Assistant"
    case none = "None"
    
    var id: String { self.rawValue }
} 