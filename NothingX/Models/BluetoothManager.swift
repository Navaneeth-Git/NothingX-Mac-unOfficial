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
    
    // Nothing earbuds UUIDs - based on ear-web repository
    private let nothingPrimaryServiceUUID = CBUUID(string: "955A1523-0FE4-F52F-A091-331D71AFD99D")
    private let nothingBatteryServiceUUID = CBUUID(string: "180F")
    private let nothingDeviceInfoServiceUUID = CBUUID(string: "180A")
    
    // Nothing characteristic UUIDs
    private let batteryLeftCharUUID = CBUUID(string: "2B91C562-8909-4B1E-93D0-8A39D7862D0F")
    private let batteryRightCharUUID = CBUUID(string: "2B91C562-8909-4B1E-93D0-8A39D7862D0E")
    private let batteryCaseCharUUID = CBUUID(string: "2B91C562-8909-4B1E-93D0-8A39D7862D0D")
    private let anc1CharUUID = CBUUID(string: "45F66627-4C7D-4321-9784-C5E7DAB34E8F")
    private let anc2CharUUID = CBUUID(string: "45F66627-4C7D-4321-9784-C5E7DAB34E8E")
    private let equalizerCharUUID = CBUUID(string: "91780BBF-F13E-43F8-B688-3D8AD3865A98")
    private let inEarDetectionCharUUID = CBUUID(string: "EB927D67-741C-4197-B30E-13A70B943AD7")
    private let lowLatencyModeCharUUID = CBUUID(string: "5DCF8DA3-50B3-4C76-93D4-DA2E4E88ACF1")
    private let gestureControlCharUUID = CBUUID(string: "83CF0A7C-5794-4437-88D2-839F8DB383DD")
    private let findMyEarbudsCharUUID = CBUUID(string: "46164F5C-BD5F-49B3-80F3-27DFEC2EFD60")
    private let firmwareRevisionCharUUID = CBUUID(string: "2A26")
    private let modelNumberCharUUID = CBUUID(string: "2A24")
    
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
                print("Starting scan for Nothing earbuds...")
                
                // Scan for all devices, since different Nothing/CMF models might advertise differently
                let options: [String: Any] = [
                    CBCentralManagerScanOptionAllowDuplicatesKey: false
                ]
                self.centralManager.scanForPeripherals(withServices: nil, options: options)
                
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
        guard let characteristic1 = discoveredCharacteristics[anc1CharUUID],
              let characteristic2 = discoveredCharacteristics[anc2CharUUID] else {
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
        
        // ANC requires sending to two characteristics
        let data = Data([modeValue])
        writeCharacteristic(characteristic1, data: data, description: "Set ANC mode to \(mode) - primary")
        writeCharacteristic(characteristic2, data: data, description: "Set ANC mode to \(mode) - secondary")
    }
    
    // Set equalizer preset
    func setEqualizerPreset(_ preset: EqualizerPreset) {
        guard let characteristic = discoveredCharacteristics[equalizerCharUUID] else {
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
        guard let characteristic = discoveredCharacteristics[equalizerCharUUID] else {
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
        guard let characteristic = discoveredCharacteristics[inEarDetectionCharUUID] else {
            reportError("In-ear detection characteristic not found")
            return
        }
        
        let value: UInt8 = enabled ? 1 : 0
        let data = Data([value])
        writeCharacteristic(characteristic, data: data, description: "Set in-ear detection to \(enabled ? "on" : "off")")
    }
    
    // Toggle low latency mode
    func toggleLowLatencyMode(_ enabled: Bool) {
        guard let characteristic = discoveredCharacteristics[lowLatencyModeCharUUID] else {
            reportError("Low latency mode characteristic not found")
            return
        }
        
        let value: UInt8 = enabled ? 1 : 0
        let data = Data([value])
        writeCharacteristic(characteristic, data: data, description: "Set low latency mode to \(enabled ? "on" : "off")")
    }
    
    // Set gesture control
    func setGestureControl(earbud: EarbudSide, gestureType: GestureType, action: GestureAction) {
        guard let characteristic = discoveredCharacteristics[gestureControlCharUUID] else {
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
        guard let characteristic = discoveredCharacteristics[findMyEarbudsCharUUID] else {
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
        
        // Debug info
        print("Checking if \(name) is a Nothing earbud")
        for device in supportedDevices {
            print("Comparing with supported device: \(device)")
            if name.contains(device) {
                print("✅ Match found: \(name) contains \(device)")
                return true
            }
        }
        
        // Fallback: check for generic "CMF" or "Nothing" keywords
        if name.contains("CMF") || name.contains("Nothing") {
            print("✅ Generic match found for \(name)")
            return true
        }
        
        print("❌ No match found for \(name)")
        return false
    }
    
    // Discover all required services
    private func discoverEarbudServices(_ peripheral: CBPeripheral) {
        print("Discovering services for Nothing earbuds...")
        // Instead of looking for specific services, discover all services first
        peripheral.discoverServices(nil)
    }
    
    // Read battery levels
    private func readBatteryLevels() {
        guard let peripheral = connectedPeripheral else {
            reportError("Not connected to a device")
            return
        }
        
        // Try the specific UUIDs first
        let batteryCharacteristics = [batteryLeftCharUUID, batteryRightCharUUID, batteryCaseCharUUID]
        for uuid in batteryCharacteristics {
            if let characteristic = discoveredCharacteristics[uuid] {
                print("Reading battery from specific characteristic: \(uuid)")
                peripheral.readValue(for: characteristic)
            }
        }
        
        // If we didn't find the specific UUIDs, look for any battery-related characteristics
        let batteryKeywords = ["battery", "batt", "level"]
        for (uuid, characteristic) in discoveredCharacteristics {
            let uuidString = uuid.uuidString.lowercased()
            
            // Skip if we already read from the specific UUIDs
            if batteryCharacteristics.contains(uuid) {
                continue
            }
            
            // Look for generic battery characteristics or standard battery service characteristics
            if batteryKeywords.contains(where: { uuidString.contains($0) }) || 
               uuidString == "2a19" {  // Standard battery level characteristic
                print("Reading from potential battery characteristic: \(uuid)")
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    // Update battery levels on the UI
    private func updateBatteryLevels(left: Int? = nil, right: Int? = nil, case: Int? = nil) {
        let currentLevels = batteryLevels
        let newLevels = (
            left ?? currentLevels.left,
            right ?? currentLevels.right,
            `case` ?? currentLevels.case
        )
        
        if newLevels != currentLevels {
            DispatchQueue.main.async { [weak self] in
                self?.batteryLevels = newLevels
            }
        }
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
            print("Found Nothing earbud: \(name ?? "Unknown")")
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
        
        // Set peripheral delegate and update connected peripheral
        peripheral.delegate = self
        connectedPeripheral = peripheral
        
        // Apply a connection option that might help maintain the connection
        // This increases the time between automatic disconnections
        peripheral.setDesiredConnectionLatency(.low, for: peripheral)
        
        // Wait a moment before discovering services to ensure the connection is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Start discovering services
            self.discoverEarbudServices(peripheral)
        }
        
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
            self.batteryLevels = (0, 0, 0)
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
        
        // Debug: Print all discovered services
        for service in services {
            print("Service found: \(service.uuid)")
            discoveredServices[service.uuid] = service
            
            // Discover all characteristics for each service
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
        
        // Debug: Print all discovered characteristics
        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.uuid) in service: \(service.uuid)")
            discoveredCharacteristics[characteristic.uuid] = characteristic
            
            // Read initial values for readable characteristics
            if characteristic.properties.contains(.read) {
                print("Reading value for characteristic: \(characteristic.uuid)")
                peripheral.readValue(for: characteristic)
            }
            
            // Subscribe to notifications if supported
            if characteristic.properties.contains(.notify) {
                print("Subscribing to notifications for: \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // After discovering all characteristics, try to read battery levels
        // Attempt to read battery even if we didn't find the exact UUIDs
        if service.uuid.uuidString.lowercased().contains("battery") || 
           service.uuid.uuidString == "180F" {
            readBatteryLevels()
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
        
        print("Received data for characteristic \(characteristic.uuid): \(data.hexDescription)")
        
        // Known battery characteristics
        if characteristic.uuid == batteryLeftCharUUID {
            if let level = parseBatteryLevel(data) {
                print("Left earbud battery: \(level)%")
                updateBatteryLevels(left: level)
            }
        } else if characteristic.uuid == batteryRightCharUUID {
            if let level = parseBatteryLevel(data) {
                print("Right earbud battery: \(level)%")
                updateBatteryLevels(right: level)
            }
        } else if characteristic.uuid == batteryCaseCharUUID {
            if let level = parseBatteryLevel(data) {
                print("Case battery: \(level)%")
                updateBatteryLevels(case: level)
            }
        } 
        // Device info characteristics
        else if characteristic.uuid == firmwareRevisionCharUUID {
            if let versionString = String(data: data, encoding: .utf8) {
                firmwareVersion = versionString
                print("Firmware version updated: \(versionString)")
            }
        } else if characteristic.uuid == modelNumberCharUUID {
            if let modelString = String(data: data, encoding: .utf8) {
                modelNumber = modelString
                print("Model number updated: \(modelString)")
            }
        } 
        // Standard battery level characteristic
        else if characteristic.uuid.uuidString.lowercased() == "2a19" {
            if let level = parseBatteryLevel(data) {
                print("Standard battery level: \(level)%")
                // Try to determine which battery this is (might be any of them)
                // For now, just update left earbud as a default
                updateBatteryLevels(left: level)
            }
        }
        // Look for any battery-related characteristics by name
        else if characteristic.uuid.uuidString.lowercased().contains("battery") || 
                characteristic.uuid.uuidString.lowercased().contains("batt") ||
                characteristic.uuid.uuidString.lowercased().contains("level") {
            if let level = parseBatteryLevel(data) {
                print("Generic battery level found: \(level)% from \(characteristic.uuid)")
                // Update the first empty battery value we find
                if batteryLevels.left == 0 {
                    updateBatteryLevels(left: level)
                } else if batteryLevels.right == 0 {
                    updateBatteryLevels(right: level)
                } else if batteryLevels.case == 0 {
                    updateBatteryLevels(case: level)
                }
            }
        }
    }
    
    private func parseBatteryLevel(_ data: Data) -> Int? {
        guard !data.isEmpty else { return nil }
        
        // Try different battery level formats
        
        // Format 1: Single byte percentage (0-100)
        if data.count == 1 {
            return Int(data[0])
        }
        
        // Format 2: Two bytes (common for some devices)
        if data.count == 2 {
            let value = UInt16(data[0]) | (UInt16(data[1]) << 8)
            return Int(min(value, 100))
        }
        
        // Format 3: First byte is the percentage in a multi-byte array
        return Int(data[0])
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




