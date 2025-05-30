import Foundation

import Combine

class EarbudManager: ObservableObject {
    // Dependencies
    private let bluetoothManager: BluetoothManager
    
    // Published properties
    @Published var equalizerPreset: EqualizerPreset = .balanced
    @Published var customEqualizerSettings: [Float] = [0, 0, 0, 0, 0, 0]
    @Published var isAdvancedEQEnabled = false
    
    @Published var ancMode: ANCMode = .off
    @Published var isPersonalizedANCEnabled = false
    
    @Published var isInEarDetectionEnabled = true
    @Published var isLowLatencyModeEnabled = false
    @Published var firmwareVersion: String = "Unknown"
    
    // Private properties
    private var cancellables = Set<AnyCancellable>()
    
    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        
        // Set up bindings
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        equalizerPreset = preset
        bluetoothManager.setEqualizerPreset(preset)
    }
    
    func setCustomEqualizerValues(_ values: [Float]) {
        customEqualizerSettings = values
        
        if equalizerPreset == .custom {
            bluetoothManager.setCustomEqualizerValues(values)
        }
    }
    
    func setANCMode(_ mode: ANCMode) {
        ancMode = mode
        bluetoothManager.setANCMode(mode)
    }
    
    func toggleAdvancedEQ(_ enabled: Bool) {
        isAdvancedEQEnabled = enabled
    }
    
    func togglePersonalizedANC(_ enabled: Bool) {
        isPersonalizedANCEnabled = enabled
    }
    
    func toggleInEarDetection(_ enabled: Bool) {
        isInEarDetectionEnabled = enabled
        bluetoothManager.toggleInEarDetection(enabled)
    }
    
    func toggleLowLatencyMode(_ enabled: Bool) {
        isLowLatencyModeEnabled = enabled
        bluetoothManager.toggleLowLatencyMode(enabled)
    }
    
    func runEarTipFitTest(completion: @escaping (EarTipFitResult) -> Void) {
        // In a real implementation, this would communicate with the earbuds
        // For now, we'll simulate a fit test result after a delay
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            let results: [EarTipFitResult] = [.good, .adjustNeeded, .poor]
            let result = results.randomElement() ?? .good
            completion(result)
        }
    }
    
    func findMyEarbuds() {
        bluetoothManager.findMyEarbuds()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Update firmware version when available
        bluetoothManager.objectWillChange
            .sink { [weak self] _ in
                self?.firmwareVersion = self?.bluetoothManager.getFirmwareVersion() ?? "Unknown"
            }
            .store(in: &cancellables)
        
        // Check for device capabilities when a device connects
        bluetoothManager.$connectedDevice
            .sink { [weak self] device in
                guard let self = self, let device = device else { return }
                
                // Reset settings based on device capabilities
                if !device.type.supportsANC {
                    self.ancMode = .off
                    self.isPersonalizedANCEnabled = false
                }
                
                if !device.type.supportsAdvancedEQ {
                    self.isAdvancedEQEnabled = false
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Enums



