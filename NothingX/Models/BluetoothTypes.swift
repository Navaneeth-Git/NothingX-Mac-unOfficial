import Foundation

// MARK: - Shared Enums for Earbuds

enum ANCMode: String, CaseIterable, Identifiable {
    case off = "Off"
    case light = "Light"
    case medium = "Medium"
    case high = "High"
    case adaptive = "Adaptive"
    case transparency = "Transparency"
    
    var id: String { self.rawValue }
    
    var isActive: Bool {
        switch self {
        case .high, .medium, .light, .adaptive:
            return true
        case .transparency, .off:
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

enum EarTipFitResult: String, CaseIterable, Identifiable {
    case good = "Good Seal"
    case adjustNeeded = "Adjustment Needed"
    case poor = "Poor Fit"
    case unsupported = "Not Supported"
    
    var id: String { self.rawValue }
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

enum FitTestStatus {
    case notStarted
    case inProgress
    case completed
}

// MARK: - Device Types

enum DeviceType {
    case ear1
    case earStick
    case ear2
    case cmfBudsPro
    case cmfBuds
    case nothingEar
    case cmfBudsPro2
    case unknown
    
    static func fromName(_ name: String) -> DeviceType {
        let lowerName = name.lowercased()
        
        if lowerName.contains("ear (1)") {
            return .ear1
        } else if lowerName.contains("ear (stick)") {
            return .earStick
        } else if lowerName.contains("ear (2)") {
            return .ear2
        } else if lowerName.contains("cmf buds pro") && lowerName.contains("2") {
            return .cmfBudsPro2
        } else if lowerName.contains("cmf buds pro") {
            return .cmfBudsPro
        } else if lowerName.contains("cmf buds") {
            return .cmfBuds
        } else if lowerName.contains("nothing ear") {
            return .nothingEar
        } else {
            return .unknown
        }
    }
    
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
            return "Unknown Device"
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
        case .ear1, .earStick, .cmfBuds, .cmfBudsPro, .unknown:
            return false
        }
    }
    
    var supportsAdvancedEQ: Bool {
        switch self {
        case .ear2, .nothingEar, .cmfBudsPro2:
            return true
        case .ear1, .earStick, .cmfBuds, .cmfBudsPro, .unknown:
            return false
        }
    }
} 