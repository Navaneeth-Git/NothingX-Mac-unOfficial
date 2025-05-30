import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    // Published properties to update the UI
    @Published var isScanning = false
    @Published var discoveredDevices: [BluetoothDevice] = []
    @Published var connectedDevice: BluetoothDevice?
    @Published var batteryLevels: (left: Int, right: Int, case: Int) = (0, 0, 0)
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var permissionError: String? = nil
    @Published var lastError: String? = nil
    
    // CoreBluetooth properties
    private var centralManager: CBCentralManager!
    private var peripherals = [CBPeripheral]()
    private var connectedPeripheral: CBPeripheral?
    
    // Service and characteristic cache
    private var discoveredServices = [CBUUID: CBService]()
    private var discoveredCharacteristics = [CBUUID: CBCharacteristic]()
    
    // Nothing earbuds UUIDs (add more specific UUIDs once you have them)
    private let nothingServiceUUIDs = [
        CBUUID(string: "0000180F-0000-1000-8000-00805F9B34FB"), // Battery Service
        CBUUID(string: "0000180A-0000-1000-8000-00805F9B34FB"), // Device Information
        CBUUID(string: "00001805-0000-1000-8000-00805F9B34FB"), // Current Time
        // Add more specific Nothing earbud service UUIDs here
    ]
    
    // Characteristics UUIDs
    private let batteryCharacteristicUUID = CBUUID(string: "00002A19-0000-1000-8000-00805F9B34FB")
    private let modelNumberCharacteristicUUID = CBUUID(string: "00002A24-0000-1000-8000-00805F9B34FB")
    private let firmwareRevisionCharacteristicUUID = CBUUID(string: "00002A26-0000-1000-8000-00805F9B34FB")
    
    // Nothing-specific characteristics (add real UUIDs when available)
    private let equalizerCharacteristicUUID = CBUUID(string: "00000001-0000-1000-8000-00805F9B34FB") // Placeholder
    private let ancModeCharacteristicUUID = CBUUID(string: "00000002-0000-1000-8000-00805F9B34FB")   // Placeholder
    private let inEarDetectionCharacteristicUUID = CBUUID(string: "00000003-0000-1000-8000-00805F9B34FB") // Placeholder
    private let lowLatencyModeCharacteristicUUID = CBUUID(string: "00000004-0000-1000-8000-00805F9B34FB") // Placeholder
    private let gestureControlCharacteristicUUID = CBUUID(string: "00000005-0000-1000-8000-00805F9B34FB") // Placeholder
    private let findMyEarbudsCharacteristicUUID = CBUUID(string: "00000006-0000-1000-8000-00805F9B34FB") // Placeholder
    
    // Supported device models
    private let supportedDevices = [
        "Nothing ear (1)",
        "Nothing ear (stick)",
        "Nothing ear (2)",
        "CMF Buds Pro",
        "CMF Buds",
        "Nothing Ear",
        "CMF Buds Pro 2"
    ]
    
    // Queue for CoreBluetooth operations
    private let bluetoothQueue = DispatchQueue(label: "com.nothingx.bluetooth", qos: .userInitiated)
    
    // Device info cache
    private var firmwareVersion: String = "Unknown"
    private var modelNumber: String = "Unknown"
    
    override init() {
        super.init()
        
        // Verify Info.plist contains required keys
        verifyBluetoothPermissions()
        
        // Define options with restoration identifier to match delegate implementation
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "com.nothingx.centralmanager"
        ]
        
        print("Initializing CBCentralManager with restoration identifier")
        
        // Initialize CBCentralManager on a specific queue to avoid main thread issues
        centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue, options: options)
    }
    
    // Verify Bluetooth permissions are in Info.plist
    private func verifyBluetoothPermissions() {
        let requiredKeys = [
            "NSBluetoothAlwaysUsageDescription",
            "NSBluetoothPeripheralUsageDescription",
            "NSBluetoothUsageDescription",
            "NSBluetoothServicesUsageDescription"
        ]
        
        let infoDictionary = Bundle.main.infoDictionary
        var missingKeys: [String] = []
        
        for key in requiredKeys {
            if infoDictionary?[key] == nil {
                missingKeys.append(key)
            }
        }
        
        if !missingKeys.isEmpty {
            let errorMessage = "Missing required Info.plist keys: \(missingKeys.joined(separator: ", "))"
            print("⚠️ \(errorMessage)")
            DispatchQueue.main.async {
                self.permissionError = errorMessage
            }
        } else {
            print("✅ All required Bluetooth permission keys found in Info.plist")
        }
    }
    
    // MARK: - Public Methods
    
    // Start scanning for devices
    func startScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.centralManager.state == .poweredOn {
                DispatchQueue.main.async {
                    self.isScanning = true
                    self.discoveredDevices = []
                    self.lastError = nil
                }
                
                self.peripherals = []
                self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
                
                // Auto-stop scan after 30 seconds
                DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
                    self?.stopScanning()
                }
            } else {
                let errorMsg = "Bluetooth is not available: \(self.centralManager.state.rawValue)"
                print(errorMsg)
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.lastError = errorMsg
                }
            }
        }
    }
    
    // Stop scanning
    func stopScanning() {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.centralManager.stopScan()
            DispatchQueue.main.async {
                self.isScanning = false
            }
        }
    }
    
    // Connect to a device
    func connect(to device: BluetoothDevice) {
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            guard let peripheral = self.peripherals.first(where: { $0.identifier == device.id }) else {
                let errorMsg = "Could not find peripheral with id: \(device.id)"
                print(errorMsg)
                DispatchQueue.main.async {
                    self.lastError = errorMsg
                }
                return
            }
            
            print("Attempting to connect to \(peripheral.name ?? "Unknown device")")
            DispatchQueue.main.async {
                self.lastError = nil
            }
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    // Disconnect from current device
    func disconnect() {
        bluetoothQueue.async { [weak self] in
            guard let self = self, let peripheral = self.connectedPeripheral else { return }
            
            print("Disconnecting from \(peripheral.name ?? "Unknown device")")
            self.centralManager.cancelPeripheralConnection(peripheral)
            
            DispatchQueue.main.async {
                self.lastError = nil
                self.discoveredServices.removeAll()
                self.discoveredCharacteristics.removeAll()
            }
        }
    }
    
    // MARK: - Earbud Control Methods
    
    // Set ANC mode
    func setANCMode(_ mode: ANCMode) {
        guard let characteristic = discoveredCharacteristics[ancModeCharacteristicUUID] else {
            reportError("ANC control characteristic not found")
            return
        }
        
        var modeValue: UInt8
        switch mode {
        case .off:
            modeValue = 0
        case .light:
            modeValue = 1
        case .medium:
            modeValue = 2
        case .high:
            modeValue = 3
        case .adaptive:
            modeValue = 4
        case .transparency:
            modeValue = 5
        }
        
        let data = Data([modeValue])
        writeCharacteristic(characteristic, data: data, description: "Set ANC mode to \(mode)")
    }
    
    // Set equalizer preset
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        guard let characteristic = discoveredCharacteristics[equalizerCharacteristicUUID] else {
            reportError("Equalizer characteristic not found")
            return
        }
        
        var presetValue: UInt8
        switch preset {
        case .balanced:
            presetValue = 0
        case .moreVoice:
            presetValue = 1
        case .moreBass:
            presetValue = 2
        case .moreTreble:
            presetValue = 3
        case .custom:
            presetValue = 4
        }
        
        let data = Data([presetValue])
        writeCharacteristic(characteristic, data: data, description: "Set equalizer preset to \(preset)")
    }
    
    // Set custom equalizer values
    func setCustomEqualizerValues(_ values: [Float]) {
        guard let characteristic = discoveredCharacteristics[equalizerCharacteristicUUID] else {
            reportError("Equalizer characteristic not found")
            return
        }
        
        // Convert float values to bytes for transmission
        var bytes = [UInt8]()
        bytes.append(4) // Custom preset identifier
        
        for value in values {
            // Convert -10 to +10 float range to 0-255 byte range
            let byteValue = UInt8(((value + 10) / 20) * 255)
            bytes.append(byteValue)
        }
        
        let data = Data(bytes)
        writeCharacteristic(characteristic, data: data, description: "Set custom equalizer values")
    }
    
    // Toggle in-ear detection
    func toggleInEarDetection(_ enabled: Bool) {
        guard let characteristic = discoveredCharacteristics[inEarDetectionCharacteristicUUID] else {
            reportError("In-ear detection characteristic not found")
            return
        }
        
        let value: UInt8 = enabled ? 1 : 0
        let data = Data([value])
        writeCharacteristic(characteristic, data: data, description: "Set in-ear detection to \(enabled ? "on" : "off")")
    }
    
    // Toggle low latency mode
    func toggleLowLatencyMode(_ enabled: Bool) {
        guard let characteristic = discoveredCharacteristics[lowLatencyModeCharacteristicUUID] else {
            reportError("Low latency mode characteristic not found")
            return
        }
        
        let value: UInt8 = enabled ? 1 : 0
        let data = Data([value])
        writeCharacteristic(characteristic, data: data, description: "Set low latency mode to \(enabled ? "on" : "off")")
    }
    
    // Set gesture control
    func setGestureControl(earbud: EarbudSide, gestureType: GestureType, action: GestureAction) {
        guard let characteristic = discoveredCharacteristics[gestureControlCharacteristicUUID] else {
            reportError("Gesture control characteristic not found")
            return
        }
        
        // Create byte array for command
        var bytes = [UInt8]()
        
        // First byte: earbud side (0 = left, 1 = right)
        bytes.append(earbud == .left ? 0 : 1)
        
        // Second byte: gesture type
        var gestureValue: UInt8
        switch gestureType {
        case .singleTap:
            gestureValue = 0
        case .doubleTap:
            gestureValue = 1
        case .tripleTap:
            gestureValue = 2
        case .holdTap:
            gestureValue = 3
        }
        bytes.append(gestureValue)
        
        // Third byte: action
        var actionValue: UInt8
        switch action {
        case .none:
            actionValue = 0
        case .playPause:
            actionValue = 1
        case .nextTrack:
            actionValue = 2
        case .previousTrack:
            actionValue = 3
        case .volumeUp:
            actionValue = 4
        case .volumeDown:
            actionValue = 5
        case .toggleANC:
            actionValue = 6
        case .voiceAssistant:
            actionValue = 7
        }
        bytes.append(actionValue)
        
        let data = Data(bytes)
        writeCharacteristic(characteristic, data: data, description: "Set \(earbud) earbud \(gestureType) to \(action)")
    }
    
    // Find my earbuds
    func findMyEarbuds() {
        guard let characteristic = discoveredCharacteristics[findMyEarbudsCharacteristicUUID] else {
            reportError("Find my earbuds characteristic not found")
            return
        }
        
        let data = Data([1]) // 1 = activate find feature
        writeCharacteristic(characteristic, data: data, description: "Activate find my earbuds")
        
        // Auto-disable after 10 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            let stopData = Data([0]) // 0 = deactivate find feature
            self.writeCharacteristic(characteristic, data: stopData, description: "Deactivate find my earbuds")
        }
    }
    
    // Get firmware version
    func getFirmwareVersion() -> String {
        return firmwareVersion
    }
    
    // Get model number
    func getModelNumber() -> String {
        return modelNumber
    }
    
    // MARK: - Private Helper Methods
    
    // Write to a characteristic
    private func writeCharacteristic(_ characteristic: CBCharacteristic, data: Data, description: String) {
        bluetoothQueue.async { [weak self] in
            guard let self = self, let peripheral = self.connectedPeripheral else {
                self?.reportError("Not connected to a device")
                return
            }
            
            print("Writing to characteristic \(characteristic.uuid): \(data.hexDescription) (\(description))")
            
            if characteristic.properties.contains(.write) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else if characteristic.properties.contains(.writeWithoutResponse) {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            } else {
                self.reportError("Characteristic does not support write operations")
            }
        }
    }
    
    // Report error to UI
    private func reportError(_ message: String) {
        print("Error: \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.lastError = message
        }
    }
    
    // Helper method to check if a device is a Nothing earbud
    private func isNothingEarbud(_ name: String?) -> Bool {
        guard let name = name else { return false }
        return supportedDevices.contains { name.contains($0) }
    }
    
    // Discover all required services
    private func discoverEarbudServices(_ peripheral: CBPeripheral) {
        peripheral.discoverServices(nothingServiceUUIDs)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Bluetooth state updated: \(central.state.rawValue)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bluetoothState = central.state
            
            switch central.state {
            case .poweredOn:
                print("Bluetooth is powered on")
            case .poweredOff:
                print("Bluetooth is powered off")
                self.discoveredDevices = []
                self.peripherals = []
                self.connectedDevice = nil
                self.connectedPeripheral = nil
                self.discoveredServices.removeAll()
                self.discoveredCharacteristics.removeAll()
            case .resetting:
                print("Bluetooth is resetting")
            case .unauthorized:
                print("Bluetooth is unauthorized")
            case .unsupported:
                print("Bluetooth is unsupported")
            case .unknown:
                print("Bluetooth state is unknown")
            @unknown default:
                print("Unknown Bluetooth state")
            }
        }
    }
    
    // Required method for state restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("Restoring Bluetooth state...")
        
        // Handle restored peripherals
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            print("Found \(restoredPeripherals.count) restored peripherals")
            
            for peripheral in restoredPeripherals {
                peripheral.delegate = self
                self.peripherals.append(peripheral)
                
                if peripheral.state == .connected {
                    self.connectedPeripheral = peripheral
                    
                    // Create a BluetoothDevice from the peripheral
                    let device = BluetoothDevice(
                        id: peripheral.identifier,
                        name: peripheral.name ?? "Unknown Device",
                        rssi: 0  // We don't have RSSI info during restoration
                    )
                    
                    // Update the UI on the main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.connectedDevice = device
                    }
                    
                    // Rediscover services
                    discoverEarbudServices(peripheral)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        
        print("Discovered device: \(name ?? "Unnamed"), RSSI: \(RSSI)")
        
        if isNothingEarbud(name), !peripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            peripherals.append(peripheral)
            let device = BluetoothDevice(id: peripheral.identifier, name: name ?? "Unknown Nothing Device", rssi: RSSI.intValue)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !self.discoveredDevices.contains(where: { $0.id == device.id }) {
                    self.discoveredDevices.append(device)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown device")")
        
        // Set peripheral delegate on the same queue
        peripheral.delegate = self
        connectedPeripheral = peripheral
        
        // Start discovering services
        discoverEarbudServices(peripheral)
        
        // Update the connected device property on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let device = self.discoveredDevices.first(where: { $0.id == peripheral.identifier }) {
                self.connectedDevice = device
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown device"): \(error?.localizedDescription ?? "No error")")
        
        // Clean up on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectedPeripheral = nil
            self.connectedDevice = nil
            self.discoveredServices.removeAll()
            self.discoveredCharacteristics.removeAll()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMsg = "Failed to connect to \(peripheral.name ?? "Unknown device"): \(error?.localizedDescription ?? "Unknown error")"
        print(errorMsg)
        
        DispatchQueue.main.async { [weak self] in
            self?.lastError = errorMsg
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            reportError("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            reportError("No services found for \(peripheral.name ?? "Unknown device")")
            return
        }
        
        print("Discovered \(services.count) services for \(peripheral.name ?? "Unknown device")")
        
        // Store services and discover characteristics
        for service in services {
            discoveredServices[service.uuid] = service
            print("Discovering characteristics for service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            reportError("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("No characteristics found for service \(service.uuid)")
            return 
        }
        
        print("Discovered \(characteristics.count) characteristics for service \(service.uuid)")
        
        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.uuid)")
            discoveredCharacteristics[characteristic.uuid] = characteristic
            
            // Read initial values for readable characteristics
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            
            // Subscribe to notifications if supported
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Handle specific characteristics
            if characteristic.uuid == batteryCharacteristicUUID {
                print("Found battery level characteristic")
            } else if characteristic.uuid == modelNumberCharacteristicUUID {
                print("Found model number characteristic")
            } else if characteristic.uuid == firmwareRevisionCharacteristicUUID {
                print("Found firmware revision characteristic")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            reportError("Error updating value for characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            print("No data received for characteristic: \(characteristic.uuid)")
            return
        }
        
        if characteristic.uuid == batteryCharacteristicUUID {
            handleBatteryLevelUpdate(data)
        } else if characteristic.uuid == modelNumberCharacteristicUUID {
            handleModelNumberUpdate(data)
        } else if characteristic.uuid == firmwareRevisionCharacteristicUUID {
            handleFirmwareRevisionUpdate(data)
        } else {
            print("Received data for characteristic \(characteristic.uuid): \(data.hexDescription)")
        }
    }
    
    private func handleBatteryLevelUpdate(_ data: Data) {
        guard !data.isEmpty else { return }
        
        // Most basic implementation - just reads the first byte as a percentage
        let batteryLevel = Int(data[0])
        print("Battery level updated: \(batteryLevel)%")
        
        // In a real implementation, we'd determine which earbud or case this is for
        // For now we're just using the same value for all components
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.batteryLevels = (batteryLevel, batteryLevel, batteryLevel)
        }
    }
    
    private func handleModelNumberUpdate(_ data: Data) {
        guard let modelString = String(data: data, encoding: .utf8) else { return }
        modelNumber = modelString
        print("Model number updated: \(modelString)")
    }
    
    private func handleFirmwareRevisionUpdate(_ data: Data) {
        guard let versionString = String(data: data, encoding: .utf8) else { return }
        firmwareVersion = versionString
        print("Firmware version updated: \(versionString)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            reportError("Error writing value to characteristic: \(error.localizedDescription)")
        } else {
            print("Successfully wrote value to characteristic: \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            reportError("Error updating notification state: \(error.localizedDescription)")
        } else {
            print("Notification state updated for \(characteristic.uuid): \(characteristic.isNotifying ? "enabled" : "disabled")")
        }
    }
}

// MARK: - Data Extension
extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - Earbud Types
enum ANCMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case light = "Light"
    case medium = "Medium"
    case high = "High"
    case adaptive = "Adaptive"
    case transparency = "Transparency"
    
    var id: String { self.rawValue }
}

enum EqualizerPreset: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case moreVoice = "More Voice"
    case moreBass = "More Bass"
    case moreTreble = "More Treble"
    case custom = "Custom"
    
    var id: String { self.rawValue }
}

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

enum GestureAction: String, CaseIterable, Identifiable {
    case none = "None"
    case playPause = "Play/Pause"
    case nextTrack = "Next Track"
    case previousTrack = "Previous Track"
    case volumeUp = "Volume Up"
    case volumeDown = "Volume Down"
    case toggleANC = "Toggle ANC"
    case voiceAssistant = "Voice Assistant"
    
    var id: String { self.rawValue }
} 