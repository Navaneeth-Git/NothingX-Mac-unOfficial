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
    
    // Private structures to track functionality
    private struct EarbudCharacteristics {
        var batteryLeft: CBCharacteristic?
        var batteryRight: CBCharacteristic?
        var batteryCase: CBCharacteristic?
        var anc: CBCharacteristic?
        var equalizer: CBCharacteristic?
        var inEarDetection: CBCharacteristic?
        var lowLatencyMode: CBCharacteristic?
        var gestureControl: CBCharacteristic?
        var findMyEarbuds: CBCharacteristic?
        var firmwareVersion: CBCharacteristic?
        var modelNumber: CBCharacteristic?
    }
    
    // Characteristics we've mapped to specific functionality
    private var mappedCharacteristics = EarbudCharacteristics()
    
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
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific ANC control")
            setCMFANCMode(mode)
            return
        }
        
        // Use mapped characteristic if available
        guard let characteristic = mappedCharacteristics.anc else {
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
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific equalizer control")
            setCMFEqualizerPreset(preset)
            return
        }
        
        // Use mapped characteristic if available
        guard let characteristic = mappedCharacteristics.equalizer else {
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
    
    // Toggle in-ear detection
    func toggleInEarDetection(_ enabled: Bool) {
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific in-ear detection control")
            setCMFInEarDetection(enabled)
            return
        }
        
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
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific low latency mode control")
            setCMFLowLatencyMode(enabled)
            return
        }
        
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
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific gesture control")
            setCMFGesture(earbud: earbud, gestureType: gestureType, action: action)
            return
        }
        
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
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific find my earbuds control")
            findCMFEarbuds()
            return
        }
        
        guard let characteristic = mappedCharacteristics.findMyEarbuds else {
            reportError("Find my earbuds characteristic not found")
            return
        }
        
        let data = Data([1]) // 1 = activate find feature
        writeCharacteristic(characteristic, data: data, description: "Activate find my earbuds")
        
        // Auto-disable after 10 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, let characteristic = self.mappedCharacteristics.findMyEarbuds else { return }
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
    
    // Set custom equalizer values
    func setCustomEqualizerValues(_ values: [Float]) {
        // Check if we're connected to CMF Buds
        if connectedDevice?.name.contains("CMF") == true {
            print("Using CMF-specific custom equalizer control")
            setCMFCustomEqualizerValues(values)
            return
        }
        
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
    
    // MARK: - CMF Buds Specific Implementation
    
    // Dedicated method for controlling CMF Buds via FE2C service
    private func sendCMFCommand(command: UInt8, parameter: UInt8 = 0) {
        guard let peripheral = connectedPeripheral else {
            reportError("Not connected to a device")
            return
        }
        
        // The exact characteristic used by ear-web for controlling CMF Buds
        let controlCharUUID = CBUUID(string: "FE2C1236-8366-4814-8EB0-01DE32100BEA")
        
        if let characteristic = discoveredCharacteristics[controlCharUUID] {
            let data = Data([command, parameter])
            print("Sending CMF command: \(data.hexDescription) to \(characteristic.uuid)")
            
            if characteristic.properties.contains(.write) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        } else {
            // Fallback to FE2C1234 if 1236 isn't available
            let fallbackUUID = CBUUID(string: "FE2C1234-8366-4814-8EB0-01DE32100BEA")
            if let fallbackChar = discoveredCharacteristics[fallbackUUID] {
                let data = Data([command, parameter])
                print("Sending CMF command to fallback characteristic: \(data.hexDescription) to \(fallbackChar.uuid)")
                
                if fallbackChar.properties.contains(.write) {
                    peripheral.writeValue(data, for: fallbackChar, type: .withResponse)
                } else {
                    peripheral.writeValue(data, for: fallbackChar, type: .withoutResponse)
                }
            } else {
                reportError("No suitable control characteristic found for CMF Buds")
            }
        }
    }
    
    // CMF Buds control commands
    private enum CMFCommand: UInt8 {
        case initialize = 0x00
        case anc = 0x01
        case getInfo = 0x02
        case reset = 0x03
        case gesture = 0x04
        case inEarDetection = 0x05
        case equalizer = 0x06
        case lowLatencyMode = 0x07
        case findMyEarbuds = 0x08
        case customEQ = 0x09
    }
    
    // Helper method to set ANC mode specifically for CMF Buds
    private func setCMFANCMode(_ mode: ANCMode) {
        var parameter: UInt8
        
        switch mode {
        case .off:
            parameter = 0x00
        case .transparency:
            parameter = 0x01
        case .light, .medium, .high, .adaptive:
            // CMF Buds don't seem to support multiple ANC levels, just ON
            parameter = 0x02
        }
        
        print("Setting CMF ANC mode to: \(mode), parameter: \(parameter)")
        sendCMFCommand(command: CMFCommand.anc.rawValue, parameter: parameter)
    }
    
    // Helper method to set equalizer for CMF Buds
    private func setCMFEqualizerPreset(_ preset: EqualizerPreset) {
        var parameter: UInt8
        
        switch preset {
        case .balanced:
            parameter = 0x00
        case .moreVoice:
            parameter = 0x01
        case .moreBass:
            parameter = 0x02
        case .moreTreble:
            parameter = 0x03
        case .custom:
            parameter = 0x04
        }
        
        print("Setting CMF equalizer preset to: \(preset), parameter: \(parameter)")
        sendCMFCommand(command: CMFCommand.equalizer.rawValue, parameter: parameter)
    }
    
    // Method to set in-ear detection for CMF Buds
    func setCMFInEarDetection(_ enabled: Bool) {
        let parameter: UInt8 = enabled ? 0x01 : 0x00
        print("Setting CMF in-ear detection to: \(enabled), parameter: \(parameter)")
        sendCMFCommand(command: CMFCommand.inEarDetection.rawValue, parameter: parameter)
    }
    
    // Method to set low latency mode for CMF Buds
    func setCMFLowLatencyMode(_ enabled: Bool) {
        let parameter: UInt8 = enabled ? 0x01 : 0x00
        print("Setting CMF low latency mode to: \(enabled), parameter: \(parameter)")
        sendCMFCommand(command: CMFCommand.lowLatencyMode.rawValue, parameter: parameter)
    }
    
    // Method to find CMF Buds
    func findCMFEarbuds() {
        print("Activating CMF find my earbuds")
        sendCMFCommand(command: CMFCommand.findMyEarbuds.rawValue, parameter: 0x01)
        
        // Auto-disable after 10 seconds
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            print("Deactivating CMF find my earbuds")
            self.sendCMFCommand(command: CMFCommand.findMyEarbuds.rawValue, parameter: 0x00)
        }
    }
    
    // Method to set gestures for CMF Buds
    func setCMFGesture(earbud: EarbudSide, gestureType: GestureType, action: GestureAction) {
        guard let peripheral = connectedPeripheral else {
            reportError("Not connected to a device")
            return
        }
        
        // The gesture command uses a different structure
        let command = CMFCommand.gesture.rawValue
        let side: UInt8 = earbud == .left ? 0x00 : 0x01
        
        var gesture: UInt8
        switch gestureType {
        case .singleTap:
            gesture = 0x00
        case .doubleTap:
            gesture = 0x01
        case .tripleTap:
            gesture = 0x02
        case .holdTap:
            gesture = 0x03
        }
        
        var actionValue: UInt8
        switch action {
        case .none:
            actionValue = 0x00
        case .playPause:
            actionValue = 0x01
        case .nextTrack:
            actionValue = 0x02
        case .previousTrack:
            actionValue = 0x03
        case .volumeUp:
            actionValue = 0x04
        case .volumeDown:
            actionValue = 0x05
        case .toggleANC:
            actionValue = 0x06
        case .voiceAssistant:
            actionValue = 0x07
        }
        
        // For gesture, we need to send a four-byte command
        let data = Data([command, side, gesture, actionValue])
        print("Setting CMF gesture: \(data.hexDescription)")
        
        // The exact characteristic used by ear-web for controlling CMF Buds
        let controlCharUUID = CBUUID(string: "FE2C1236-8366-4814-8EB0-01DE32100BEA")
        
        if let characteristic = discoveredCharacteristics[controlCharUUID] {
            if characteristic.properties.contains(.write) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            }
        } else {
            // Fallback to FE2C1234 if 1236 isn't available
            let fallbackUUID = CBUUID(string: "FE2C1234-8366-4814-8EB0-01DE32100BEA")
            if let fallbackChar = discoveredCharacteristics[fallbackUUID] {
                if fallbackChar.properties.contains(.write) {
                    peripheral.writeValue(data, for: fallbackChar, type: .withResponse)
                } else {
                    peripheral.writeValue(data, for: fallbackChar, type: .withoutResponse)
                }
            } else {
                reportError("No suitable control characteristic found for CMF Buds")
            }
        }
    }
    
    // Set custom equalizer values for CMF Buds
    private func setCMFCustomEqualizerValues(_ values: [Float]) {
        // First, set the EQ mode to custom
        print("Setting CMF EQ mode to custom")
        sendCMFCommand(command: CMFCommand.equalizer.rawValue, parameter: 0x04)
        
        // Then set each band value
        guard let peripheral = connectedPeripheral else {
            reportError("Not connected to a device")
            return
        }
        
        // The exact characteristic used by ear-web for controlling CMF Buds
        let controlCharUUID = CBUUID(string: "FE2C1236-8366-4814-8EB0-01DE32100BEA")
        
        if let characteristic = discoveredCharacteristics[controlCharUUID] {
            // Send each band value
            for (index, value) in values.enumerated() {
                // Convert float value (-10 to +10) to 0-100 range
                let scaledValue = UInt8(((value + 10.0) / 20.0) * 100.0)
                let data = Data([CMFCommand.customEQ.rawValue, UInt8(index), scaledValue])
                
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.1) {
                    print("Setting CMF custom EQ band \(index) to \(value) (\(scaledValue))")
                    
                    if characteristic.properties.contains(.write) {
                        peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    } else {
                        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                    }
                }
            }
        } else {
            // Fallback to FE2C1234 if 1236 isn't available
            let fallbackUUID = CBUUID(string: "FE2C1234-8366-4814-8EB0-01DE32100BEA")
            if let fallbackChar = discoveredCharacteristics[fallbackUUID] {
                // Send each band value
                for (index, value) in values.enumerated() {
                    // Convert float value (-10 to +10) to 0-100 range
                    let scaledValue = UInt8(((value + 10.0) / 20.0) * 100.0)
                    let data = Data([CMFCommand.customEQ.rawValue, UInt8(index), scaledValue])
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.1) {
                        print("Setting CMF custom EQ band \(index) to \(value) (\(scaledValue))")
                        
                        if fallbackChar.properties.contains(.write) {
                            peripheral.writeValue(data, for: fallbackChar, type: .withResponse)
                        } else {
                            peripheral.writeValue(data, for: fallbackChar, type: .withoutResponse)
                        }
                    }
                }
            } else {
                reportError("No suitable control characteristic found for CMF Buds")
            }
        }
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
        
        // Read from mapped battery characteristics
        if let leftBatteryChar = mappedCharacteristics.batteryLeft {
            print("Reading left battery level")
            peripheral.readValue(for: leftBatteryChar)
        }
        
        if let rightBatteryChar = mappedCharacteristics.batteryRight {
            print("Reading right battery level")
            peripheral.readValue(for: rightBatteryChar)
        }
        
        if let caseBatteryChar = mappedCharacteristics.batteryCase {
            print("Reading case battery level")
            peripheral.readValue(for: caseBatteryChar)
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
    
    // Map discovered characteristics to functionality
    private func mapCharacteristics() {
        print("Mapping discovered characteristics to functionality...")
        
        // Try the exact UUIDs first
        if let char = discoveredCharacteristics[batteryLeftCharUUID] {
            mappedCharacteristics.batteryLeft = char
            print("Found exact match for left battery")
        }
        
        if let char = discoveredCharacteristics[batteryRightCharUUID] {
            mappedCharacteristics.batteryRight = char
            print("Found exact match for right battery")
        }
        
        if let char = discoveredCharacteristics[batteryCaseCharUUID] {
            mappedCharacteristics.batteryCase = char
            print("Found exact match for case battery")
        }
        
        if let char = discoveredCharacteristics[anc1CharUUID] {
            mappedCharacteristics.anc = char
            print("Found exact match for ANC")
        }
        
        if let char = discoveredCharacteristics[equalizerCharUUID] {
            mappedCharacteristics.equalizer = char
            print("Found exact match for equalizer")
        }
        
        // If we didn't find exact matches, try to map based on names/patterns
        if mappedCharacteristics.batteryLeft == nil || 
           mappedCharacteristics.batteryRight == nil || 
           mappedCharacteristics.batteryCase == nil {
            mapBatteryCharacteristics()
        }
        
        if mappedCharacteristics.anc == nil {
            mapANCCharacteristics()
        }
        
        if mappedCharacteristics.equalizer == nil {
            mapEqualizerCharacteristics()
        }
        
        // Map control characteristics
        mapControlCharacteristics()
        
        // Print mapping results
        printMappingResults()
    }
    
    // Map battery characteristics based on patterns
    private func mapBatteryCharacteristics() {
        let batteryKeywords = ["battery", "batt", "level", "power"]
        
        for (uuid, characteristic) in discoveredCharacteristics {
            let uuidString = uuid.uuidString.lowercased()
            
            // Standard battery level characteristic
            if uuidString == "2a19" {
                if mappedCharacteristics.batteryLeft == nil {
                    mappedCharacteristics.batteryLeft = characteristic
                    print("Mapped standard battery characteristic to left earbud")
                } else if mappedCharacteristics.batteryRight == nil {
                    mappedCharacteristics.batteryRight = characteristic
                    print("Mapped standard battery characteristic to right earbud")
                } else if mappedCharacteristics.batteryCase == nil {
                    mappedCharacteristics.batteryCase = characteristic
                    print("Mapped standard battery characteristic to case")
                }
                continue
            }
            
            // Look for patterns in UUID or name
            if batteryKeywords.contains(where: { uuidString.contains($0) }) {
                if uuidString.contains("left") && mappedCharacteristics.batteryLeft == nil {
                    mappedCharacteristics.batteryLeft = characteristic
                    print("Mapped \(uuid) to left earbud battery based on name")
                } else if uuidString.contains("right") && mappedCharacteristics.batteryRight == nil {
                    mappedCharacteristics.batteryRight = characteristic
                    print("Mapped \(uuid) to right earbud battery based on name")
                } else if uuidString.contains("case") && mappedCharacteristics.batteryCase == nil {
                    mappedCharacteristics.batteryCase = characteristic
                    print("Mapped \(uuid) to case battery based on name")
                } else if mappedCharacteristics.batteryLeft == nil {
                    mappedCharacteristics.batteryLeft = characteristic
                    print("Mapped \(uuid) to left earbud battery as default")
                } else if mappedCharacteristics.batteryRight == nil {
                    mappedCharacteristics.batteryRight = characteristic
                    print("Mapped \(uuid) to right earbud battery as default")
                } else if mappedCharacteristics.batteryCase == nil {
                    mappedCharacteristics.batteryCase = characteristic
                    print("Mapped \(uuid) to case battery as default")
                }
            }
        }
        
        // For CMF Buds, try specific service FE2C which seems to be the main service
        if let fe2c = discoveredServices[CBUUID(string: "FE2C")] {
            if let characteristics = fe2c.characteristics {
                // Try to identify battery characteristics within this service
                for characteristic in characteristics {
                    if mappedCharacteristics.batteryLeft == nil {
                        mappedCharacteristics.batteryLeft = characteristic
                        print("Mapped \(characteristic.uuid) from FE2C service to left battery")
                        break
                    }
                }
            }
        }
    }
    
    // Map ANC characteristics based on patterns
    private func mapANCCharacteristics() {
        let ancKeywords = ["anc", "noise", "cancel", "ambient", "transparency", "mode"]
        
        for (uuid, characteristic) in discoveredCharacteristics {
            let uuidString = uuid.uuidString.lowercased()
            
            if ancKeywords.contains(where: { uuidString.contains($0) }) {
                mappedCharacteristics.anc = characteristic
                print("Mapped \(uuid) to ANC based on name")
                break
            }
        }
        
        // If we still don't have ANC, try the FE2C service which seems to be the main service for CMF
        if mappedCharacteristics.anc == nil, let fe2c = discoveredServices[CBUUID(string: "FE2C")] {
            if let characteristics = fe2c.characteristics, characteristics.count > 0 {
                // For CMF Buds, the first characteristic that supports write might be the control characteristic
                for characteristic in characteristics {
                    if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                        mappedCharacteristics.anc = characteristic
                        print("Mapped \(characteristic.uuid) from FE2C service to ANC as a fallback")
                        break
                    }
                }
            }
        }
    }
    
    // Map equalizer characteristics based on patterns
    private func mapEqualizerCharacteristics() {
        let eqKeywords = ["eq", "equalizer", "equaliser", "audio", "sound"]
        
        for (uuid, characteristic) in discoveredCharacteristics {
            let uuidString = uuid.uuidString.lowercased()
            
            if eqKeywords.contains(where: { uuidString.contains($0) }) {
                mappedCharacteristics.equalizer = characteristic
                print("Mapped \(uuid) to equalizer based on name")
                break
            }
        }
        
        // Try the FE2C service as a fallback
        if mappedCharacteristics.equalizer == nil, mappedCharacteristics.anc != nil {
            // If we have ANC, use a different characteristic from the same service for EQ
            if let anc = mappedCharacteristics.anc {
                let service = anc.service
                if let characteristics = service?.characteristics {
                    for characteristic in characteristics {
                        if characteristic.uuid != anc.uuid && 
                           (characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse)) {
                            mappedCharacteristics.equalizer = characteristic
                            print("Mapped \(characteristic.uuid) to equalizer as a fallback")
                            break
                        }
                    }
                }
            }
        }
    }
    
    // Map other control characteristics
    private func mapControlCharacteristics() {
        // For gesture control, we'll look for any writable characteristics
        for (uuid, characteristic) in discoveredCharacteristics {
            if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                if mappedCharacteristics.gestureControl == nil {
                    mappedCharacteristics.gestureControl = characteristic
                    print("Mapped \(uuid) to gesture control")
                } else if mappedCharacteristics.findMyEarbuds == nil {
                    mappedCharacteristics.findMyEarbuds = characteristic
                    print("Mapped \(uuid) to find my earbuds")
                }
            }
        }
        
        // Try to find firmware and model characteristics
        let infoKeywords = ["firmware", "version", "model", "info"]
        for (uuid, characteristic) in discoveredCharacteristics {
            let uuidString = uuid.uuidString.lowercased()
            
            if infoKeywords.contains(where: { uuidString.contains($0) }) {
                if mappedCharacteristics.firmwareVersion == nil {
                    mappedCharacteristics.firmwareVersion = characteristic
                    print("Mapped \(uuid) to firmware version")
                } else if mappedCharacteristics.modelNumber == nil {
                    mappedCharacteristics.modelNumber = characteristic
                    print("Mapped \(uuid) to model number")
                }
            } else if uuid.uuidString == "2A26" {
                mappedCharacteristics.firmwareVersion = characteristic
                print("Mapped standard firmware version characteristic")
            } else if uuid.uuidString == "2A24" {
                mappedCharacteristics.modelNumber = characteristic
                print("Mapped standard model number characteristic")
            }
        }
    }
    
    // Print mapping results for debugging
    private func printMappingResults() {
        print("\n--- CHARACTERISTIC MAPPING RESULTS ---")
        print("Battery Left: \(mappedCharacteristics.batteryLeft?.uuid.uuidString ?? "Not mapped")")
        print("Battery Right: \(mappedCharacteristics.batteryRight?.uuid.uuidString ?? "Not mapped")")
        print("Battery Case: \(mappedCharacteristics.batteryCase?.uuid.uuidString ?? "Not mapped")")
        print("ANC: \(mappedCharacteristics.anc?.uuid.uuidString ?? "Not mapped")")
        print("Equalizer: \(mappedCharacteristics.equalizer?.uuid.uuidString ?? "Not mapped")")
        print("Gesture Control: \(mappedCharacteristics.gestureControl?.uuid.uuidString ?? "Not mapped")")
        print("Find My Earbuds: \(mappedCharacteristics.findMyEarbuds?.uuid.uuidString ?? "Not mapped")")
        print("-------------------------------------\n")
    }
    
    // Try to send a common command to the main CMF service (FE2C)
    private func probeCMFService() {
        guard let peripheral = connectedPeripheral else {
            reportError("Not connected to a device")
            return
        }
        
        // Look for the main CMF service
        if let fe2cService = discoveredServices[CBUUID(string: "FE2C")],
           let characteristics = fe2cService.characteristics {
            
            print("Probing CMF FE2C service with \(characteristics.count) characteristics")
            
            // Try to write to characteristics that support it
            for characteristic in characteristics {
                if characteristic.properties.contains(.write) || 
                   characteristic.properties.contains(.writeWithoutResponse) {
                    
                    // Try different common commands (0x01, 0x02, 0x03) that might trigger a response
                    let commands: [UInt8] = [0x01, 0x02, 0x03]
                    
                    for (index, command) in commands.enumerated() {
                        let data = Data([command])
                        
                        // Delay each command slightly to avoid overwhelming the device
                        DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.5) { [weak self] in
                            guard let self = self else { return }
                            print("Sending probe command \(command) to \(characteristic.uuid)")
                            self.writeCharacteristic(characteristic, data: data, description: "CMF probe command")
                        }
                    }
                }
            }
            
            // After probing, add a fallback for ANC and EQ if they're not mapped yet
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                
                if self.mappedCharacteristics.anc == nil {
                    // Find a writable characteristic to use for ANC
                    for characteristic in characteristics {
                        if characteristic.properties.contains(.write) || 
                           characteristic.properties.contains(.writeWithoutResponse) {
                            self.mappedCharacteristics.anc = characteristic
                            print("Set fallback ANC characteristic to \(characteristic.uuid)")
                            break
                        }
                    }
                }
                
                if self.mappedCharacteristics.equalizer == nil && characteristics.count > 1 {
                    // Use a different characteristic for equalizer
                    for characteristic in characteristics {
                        if characteristic != self.mappedCharacteristics.anc &&
                           (characteristic.properties.contains(.write) || 
                            characteristic.properties.contains(.writeWithoutResponse)) {
                            self.mappedCharacteristics.equalizer = characteristic
                            print("Set fallback equalizer characteristic to \(characteristic.uuid)")
                            break
                        }
                    }
                }
                
                self.printMappingResults()
            }
        }
    }
    
    // Initialize CMF Buds with the correct protocol
    private func initializeCMFBuds() {
        print("Initializing CMF Buds...")
        
        // CMF Buds need an explicit initialization command first
        sendCMFCommand(command: CMFCommand.initialize.rawValue, parameter: 0x01)
        
        // Then request initial states with a delay between commands
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            print("Requesting CMF Buds status...")
            
            // Query current settings
            let initCommands: [(UInt8, UInt8, String)] = [
                (CMFCommand.anc.rawValue, 0xFF, "Get ANC status"),
                (CMFCommand.equalizer.rawValue, 0xFF, "Get EQ settings"),
                (CMFCommand.inEarDetection.rawValue, 0xFF, "Get in-ear detection status"),
                (CMFCommand.lowLatencyMode.rawValue, 0xFF, "Get low latency mode status")
            ]
            
            // Send each command with a small delay between them
            for (index, (command, parameter, description)) in initCommands.enumerated() {
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(index) * 0.2) { [weak self] in
                    guard let self = self else { return }
                    print("Sending CMF query: \(description)")
                    self.sendCMFCommand(command: command, parameter: parameter)
                }
            }
        }
        
        // Request battery levels
        readCMFBatteryLevels()
    }
    
    // Specifically read CMF Buds battery levels
    private func readCMFBatteryLevels() {
        // For CMF Buds, FE2C1233 characteristic contains battery information
        let batteryCharUUID = CBUUID(string: "FE2C1233-8366-4814-8EB0-01DE32100BEA")
        
        if let characteristic = discoveredCharacteristics[batteryCharUUID],
           let peripheral = connectedPeripheral {
            print("Reading CMF battery levels from \(characteristic.uuid)")
            peripheral.readValue(for: characteristic)
        } else {
            print("CMF battery characteristic not found")
        }
    }
    
    // Handle characteristic updates specifically for CMF Buds
    private func handleCMFCharacteristicUpdate(_ characteristic: CBCharacteristic, data: Data) {
        print("Handling CMF characteristic update for \(characteristic.uuid): \(data.hexDescription)")
        
        // FE2C1233 is the battery characteristic for CMF Buds
        if characteristic.uuid.uuidString == "FE2C1233-8366-4814-8EB0-01DE32100BEA" {
            if data.count >= 3 {
                // The first byte is left earbud, second is right, third is case
                let leftLevel = Int(data[0])
                let rightLevel = Int(data[1])
                let caseLevel = Int(data[2])
                
                print("CMF battery levels - Left: \(leftLevel)%, Right: \(rightLevel)%, Case: \(caseLevel)%")
                
                // Only update if values are within reasonable range (0-100)
                if leftLevel >= 0 && leftLevel <= 100 &&
                   rightLevel >= 0 && rightLevel <= 100 &&
                   caseLevel >= 0 && caseLevel <= 100 {
                    updateBatteryLevels(left: leftLevel, right: rightLevel, case: caseLevel)
                }
            }
        }
        // FE2C1234 is one control characteristic
        else if characteristic.uuid.uuidString == "FE2C1234-8366-4814-8EB0-01DE32100BEA" {
            handleCMFControlResponse(data)
        }
        // FE2C1236 is another control characteristic
        else if characteristic.uuid.uuidString == "FE2C1236-8366-4814-8EB0-01DE32100BEA" {
            handleCMFControlResponse(data)
        }
    }
    
    // Handle control responses from CMF Buds
    private func handleCMFControlResponse(_ data: Data) {
        guard data.count >= 2 else { return }
        
        let command = data[0]
        let parameter = data[1]
        
        switch command {
        case CMFCommand.anc.rawValue:
            print("Received ANC status: \(parameter)")
            // You could update UI here based on the ANC status
            
        case CMFCommand.equalizer.rawValue:
            print("Received EQ status: \(parameter)")
            // You could update UI here based on the EQ status
            
        case CMFCommand.inEarDetection.rawValue:
            print("Received in-ear detection status: \(parameter)")
            // You could update UI here based on the in-ear detection status
            
        case CMFCommand.lowLatencyMode.rawValue:
            print("Received low latency mode status: \(parameter)")
            // You could update UI here based on the low latency mode status
            
        default:
            print("Received unknown command response: \(command), parameter: \(parameter)")
        }
    }
    
    // Parse battery level from characteristic data
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
                self.lastError = nil
            case .poweredOff:
                print("Bluetooth is powered off")
                self.lastError = "Bluetooth is turned off. Please enable Bluetooth in System Settings and try again."
                self.discoveredDevices = []
                self.peripherals = []
                self.connectedDevice = nil
                self.connectedPeripheral = nil
                self.discoveredServices.removeAll()
                self.discoveredCharacteristics.removeAll()
            case .resetting:
                print("Bluetooth is resetting")
                self.lastError = "Bluetooth is resetting. Please wait a moment and try again."
            case .unauthorized:
                print("Bluetooth is unauthorized")
                self.lastError = "Bluetooth access is not authorized. Please check permissions in System Settings."
            case .unsupported:
                print("Bluetooth is unsupported")
                self.checkBluetoothHardware()
                self.lastError = "Bluetooth is not supported on this device or is unavailable. Please check your Bluetooth settings."
            case .unknown:
                print("Bluetooth state is unknown")
                self.lastError = "Bluetooth state is unknown. Please check your Bluetooth settings."
            @unknown default:
                print("Unknown Bluetooth state")
                self.lastError = "Unknown Bluetooth state. Please check your Bluetooth settings."
            }
        }
    }
    
    // Check Bluetooth hardware availability
    private func checkBluetoothHardware() {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print("Bluetooth hardware info:\n\(output)")
                
                // Check if hardware is disabled
                if output.contains("State: Off") {
                    print("⚠️ Bluetooth hardware is turned off")
                    self.lastError = "Bluetooth is turned off. Please enable Bluetooth in System Settings."
                }
                
                // Check if hardware is missing
                if output.contains("No Controller Found") {
                    print("⚠️ No Bluetooth controller found")
                    self.lastError = "No Bluetooth controller was found on this device."
                }
            }
        } catch {
            print("Error checking Bluetooth hardware: \(error)")
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
        
        // Check if we've discovered all services and characteristics
        let pendingServiceDiscoveries = peripheral.services?.filter { 
            $0.characteristics == nil 
        } ?? []
        
        if pendingServiceDiscoveries.isEmpty {
            print("All services and characteristics discovered")
            
            // Check if this is a CMF device
            if peripheral.name?.contains("CMF") == true {
                print("Detected CMF Buds, using CMF-specific initialization")
                
                // First, try to find the key CMF characteristics
                let fe2c1233 = discoveredCharacteristics[CBUUID(string: "FE2C1233-8366-4814-8EB0-01DE32100BEA")]
                let fe2c1236 = discoveredCharacteristics[CBUUID(string: "FE2C1236-8366-4814-8EB0-01DE32100BEA")]
                let fe2c1234 = discoveredCharacteristics[CBUUID(string: "FE2C1234-8366-4814-8EB0-01DE32100BEA")]
                
                if fe2c1233 != nil || fe2c1236 != nil || fe2c1234 != nil {
                    print("Found CMF-specific characteristics, initializing...")
                    
                    // Map characteristics for future use
                    mapCharacteristics()
                    
                    // Initialize CMF Buds with the correct protocol
                    initializeCMFBuds()
                } else {
                    print("CMF device detected but specific characteristics not found")
                    mapCharacteristics()
                    readBatteryLevels()
                }
            } else {
                // For other Nothing earbuds, use the standard approach
                print("Using standard Nothing earbuds initialization")
                mapCharacteristics()
                readBatteryLevels()
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
        
        print("Received data for characteristic \(characteristic.uuid): \(data.hexDescription)")
        
        // Check if this is a CMF Buds characteristic
        if peripheral.name?.contains("CMF") == true {
            // Handle FE2C service characteristics
            if characteristic.service?.uuid.uuidString == "FE2C" {
                handleCMFCharacteristicUpdate(characteristic, data: data)
                return
            }
            
            // Also check for specific characteristic UUIDs
            if characteristic.uuid.uuidString.starts(with: "FE2C") {
                handleCMFCharacteristicUpdate(characteristic, data: data)
                return
            }
        }
        
        // Standard handler for other characteristics
        // Check if this is a battery characteristic from our mapping
        if characteristic == mappedCharacteristics.batteryLeft {
            if let level = parseBatteryLevel(data) {
                print("Left earbud battery: \(level)%")
                updateBatteryLevels(left: level)
            }
        } else if characteristic == mappedCharacteristics.batteryRight {
            if let level = parseBatteryLevel(data) {
                print("Right earbud battery: \(level)%")
                updateBatteryLevels(right: level)
            }
        } else if characteristic == mappedCharacteristics.batteryCase {
            if let level = parseBatteryLevel(data) {
                print("Case battery: \(level)%")
                updateBatteryLevels(case: level)
            }
        } 
        // Known battery characteristics by UUID
        else if characteristic.uuid == batteryLeftCharUUID {
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




