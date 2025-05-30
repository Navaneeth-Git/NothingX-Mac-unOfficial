import Foundation
import CoreBluetooth

struct BluetoothDevice: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
    
    // Default device type, can be updated once more device details are known
    var type: EarbudType = .unknown
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

enum EarbudType {
    case ear1
    case earStick
    case ear2
    case cmfBudsPro
    case cmfBuds
    case nothingEar
    case cmfBudsPro2
    case unknown
    
    var displayName: String {
        switch self {
        case .ear1:
            return "Nothing ear (1)"
        case .earStick:
            return "Nothing ear (stick)"
        case .ear2:
            return "Nothing ear (2)"
        case .cmfBudsPro:
            return "CMF Buds Pro"
        case .cmfBuds:
            return "CMF Buds"
        case .nothingEar:
            return "Nothing Ear"
        case .cmfBudsPro2:
            return "CMF Buds Pro 2"
        case .unknown:
            return "Unknown Nothing Device"
        }
    }
    
    var supportsANC: Bool {
        switch self {
        case .ear1, .ear2, .cmfBudsPro, .nothingEar, .cmfBudsPro2:
            return true
        case .earStick, .cmfBuds, .unknown:
            return false
        }
    }
    
    var supportsPersonalizedANC: Bool {
        switch self {
        case .ear2, .nothingEar, .cmfBudsPro2:
            return true
        case .ear1, .earStick, .cmfBudsPro, .cmfBuds, .unknown:
            return false
        }
    }
    
    var supportsAdvancedEQ: Bool {
        switch self {
        case .ear2, .nothingEar, .cmfBudsPro2:
            return true
        case .ear1, .earStick, .cmfBudsPro, .cmfBuds, .unknown:
            return false
        }
    }
    
    static func fromName(_ name: String) -> EarbudType {
        if name.contains("ear (1)") {
            return .ear1
        } else if name.contains("ear (stick)") {
            return .earStick
        } else if name.contains("ear (2)") {
            return .ear2
        } else if name.contains("CMF Buds Pro 2") {
            return .cmfBudsPro2
        } else if name.contains("CMF Buds Pro") {
            return .cmfBudsPro
        } else if name.contains("CMF Buds") {
            return .cmfBuds
        } else if name.contains("Nothing Ear") {
            return .nothingEar
        } else {
            return .unknown
        }
    }
} 