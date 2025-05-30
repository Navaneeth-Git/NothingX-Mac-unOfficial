import Foundation

import CoreBluetooth

struct BluetoothDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let type: DeviceType
    
    init(id: UUID, name: String, rssi: Int) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.type = DeviceType.fromName(name)
    }
}


