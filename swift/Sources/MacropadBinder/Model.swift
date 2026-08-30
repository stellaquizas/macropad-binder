import Foundation

enum ControlID: String, CaseIterable, Identifiable, Codable, Hashable {
    case key1, key2, key3
    case knobCCW, knobPress, knobCW

    var id: String { rawValue }

    /// Firmware slots run from the end furthest from the knob.
    /// Physical left→right with knob on the left is slot 3, 2, 1.
    var slot: UInt8 {
        switch self {
        case .key1: return 3
        case .key2: return 2
        case .key3: return 1
        case .knobCCW: return 16
        case .knobPress: return 17
        case .knobCW: return 18
        }
    }

    var title: String {
        switch self {
        case .key1: return "Key 1"
        case .key2: return "Key 2"
        case .key3: return "Key 3"
        case .knobCCW: return "Anti-clockwise"
        case .knobPress: return "Knob click"
        case .knobCW: return "Clockwise"
        }
    }

    var shortTitle: String {
        switch self {
        case .key1: return "1"
        case .key2: return "2"
        case .key3: return "3"
        case .knobCCW: return "↺"
        case .knobPress: return "●"
        case .knobCW: return "↻"
        }
    }
}

enum PadEvent: Equatable {
    case key(mods: UInt8, code: UInt8)
    case media(UInt16)
    case mouse(MouseAction)
}

enum BindingKind: String, Codable {
    case empty, key, media, mouse
}

struct KeyStep: Codable, Hashable {
    var mods: UInt8
    var code: UInt8
}

enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case leftClick, rightClick, middleClick, wheelUp, wheelDown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .leftClick: return "Left click"
        case .rightClick: return "Right click"
        case .middleClick: return "Middle click"
        case .wheelUp: return "Wheel up"
        case .wheelDown: return "Wheel down"
        }
    }
}

struct PadBinding: Codable, Hashable {
    var kind: BindingKind
    var steps: [KeyStep]
    var media: UInt16
    var mouse: MouseAction

    static let empty = PadBinding(kind: .empty, steps: [], media: 0, mouse: .leftClick)

    static func key(_ mods: UInt8, _ code: UInt8) -> PadBinding {
        PadBinding(kind: .key, steps: [KeyStep(mods: mods, code: code)], media: 0, mouse: .leftClick)
    }

    static func media(_ usage: UInt16) -> PadBinding {
        PadBinding(kind: .media, steps: [], media: usage, mouse: .leftClick)
    }

    var isEmpty: Bool {
        switch kind {
        case .empty: return true
        case .key:
            return steps.isEmpty || steps.allSatisfy { $0.mods == 0 && $0.code == 0 }
        case .media: return media == 0
        case .mouse: return false
        }
    }

    var label: String { macLabel }

    var macLabel: String { named(host: .mac) }
    var winLabel: String { named(host: .windows) }

    var dualLabel: String {
        macLabel == winLabel ? macLabel : "\(macLabel)  ·  \(winLabel)"
    }

    func matches(_ event: PadEvent) -> Bool {
        switch (kind, event) {
        case (.key, .key(let mods, let code)):
            return steps.contains { $0.mods == mods && $0.code == code }
        case (.media, .media(let usage)):
            return media == usage
        case (.mouse, .mouse(let action)):
            return mouse == action
        default:
            return false
        }
    }

    private func named(host: HIDNames.Host) -> String {
        switch kind {
        case .empty:
            return "—"
        case .key:
            return steps.map { HIDNames.chord($0.mods, $0.code, host: host) }.joined(separator: " · ")
        case .media:
            return HIDNames.media(media)
        case .mouse:
            return mouse.label
        }
    }
}

struct LayerProfile: Codable, Hashable {
    var bindings: [ControlID: PadBinding]

    static var blank: LayerProfile {
        LayerProfile(bindings: Dictionary(uniqueKeysWithValues: ControlID.allCases.map { ($0, .empty) }))
    }

    subscript(_ id: ControlID) -> PadBinding {
        get { bindings[id] ?? .empty }
        set { bindings[id] = newValue }
    }
}

struct PadProfile: Codable, Hashable {
    var layers: [LayerProfile]

    static var blank: PadProfile {
        PadProfile(layers: [.blank, .blank, .blank])
    }
}

struct BindingDiff: Identifiable {
    let id = UUID()
    let layer: Int
    let control: ControlID
    let from: String
    let to: String
}

enum MediaPreset: CaseIterable, Identifiable {
    case mute, volUp, volDown, play, next, prev, stop
    var id: String { label }
    var usage: UInt16 {
        switch self {
        case .mute: return 0xE2
        case .volUp: return 0xE9
        case .volDown: return 0xEA
        case .play: return 0xCD
        case .next: return 0xB5
        case .prev: return 0xB6
        case .stop: return 0xB7
        }
    }
    var label: String {
        switch self {
        case .mute: return "Mute"
        case .volUp: return "Volume +"
        case .volDown: return "Volume −"
        case .play: return "Play / Pause"
        case .next: return "Next"
        case .prev: return "Previous"
        case .stop: return "Stop"
        }
    }
}
