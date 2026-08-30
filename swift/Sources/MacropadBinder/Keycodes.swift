import Foundation
import AppKit

enum HIDNames {
    static let keys: [UInt8: String] = [
        0x04: "A", 0x05: "B", 0x06: "C", 0x07: "D", 0x08: "E", 0x09: "F",
        0x0A: "G", 0x0B: "H", 0x0C: "I", 0x0D: "J", 0x0E: "K", 0x0F: "L",
        0x10: "M", 0x11: "N", 0x12: "O", 0x13: "P", 0x14: "Q", 0x15: "R",
        0x16: "S", 0x17: "T", 0x18: "U", 0x19: "V", 0x1A: "W", 0x1B: "X",
        0x1C: "Y", 0x1D: "Z",
        0x1E: "1", 0x1F: "2", 0x20: "3", 0x21: "4", 0x22: "5", 0x23: "6",
        0x24: "7", 0x25: "8", 0x26: "9", 0x27: "0",
        0x28: "Enter", 0x29: "Esc", 0x2A: "⌫", 0x2B: "Tab", 0x2C: "Space",
        0x2D: "-", 0x2E: "=", 0x2F: "[", 0x30: "]", 0x31: "\\",
        0x33: ";", 0x34: "'", 0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/",
        0x39: "Caps",
        0x3A: "F1", 0x3B: "F2", 0x3C: "F3", 0x3D: "F4", 0x3E: "F5", 0x3F: "F6",
        0x40: "F7", 0x41: "F8", 0x42: "F9", 0x43: "F10", 0x44: "F11", 0x45: "F12",
        0x46: "PrtSc", 0x47: "ScrLk", 0x48: "Pause",
        0x49: "Ins", 0x4A: "Home", 0x4B: "PgUp", 0x4C: "Del", 0x4D: "End", 0x4E: "PgDn",
        0x4F: "→", 0x50: "←", 0x51: "↓", 0x52: "↑",
        0x7F: "Mute", 0x80: "Vol+", 0x81: "Vol-",
    ]

    static let mediaUsages: [UInt16: String] = [
        0xE2: "Mute", 0xE9: "Vol+", 0xEA: "Vol-", 0xCD: "Play/Pause",
        0xB5: "Next", 0xB6: "Prev", 0xB7: "Stop", 0x183: "Media player",
    ]

    static func key(_ code: UInt8) -> String {
        keys[code] ?? String(format: "0x%02X", code)
    }

    static func media(_ usage: UInt16) -> String {
        mediaUsages[usage] ?? String(format: "Media 0x%04X", usage)
    }

    enum Host {
        case mac, windows
    }

    static func mods(_ m: UInt8, host: Host = .mac) -> String {
        switch host {
        case .mac:
            var parts: [String] = []
            if m & 0x01 != 0 { parts.append("⌃") }
            if m & 0x02 != 0 { parts.append("⇧") }
            if m & 0x04 != 0 { parts.append("⌥") }
            if m & 0x08 != 0 { parts.append("⌘") }
            if m & 0x10 != 0 { parts.append("r⌃") }
            if m & 0x20 != 0 { parts.append("r⇧") }
            if m & 0x40 != 0 { parts.append("r⌥") }
            if m & 0x80 != 0 { parts.append("r⌘") }
            return parts.joined()
        case .windows:
            var parts: [String] = []
            if m & 0x01 != 0 { parts.append("Ctrl+") }
            if m & 0x02 != 0 { parts.append("Shift+") }
            if m & 0x04 != 0 { parts.append("Alt+") }
            if m & 0x08 != 0 { parts.append("Win+") }
            if m & 0x10 != 0 { parts.append("RCtrl+") }
            if m & 0x20 != 0 { parts.append("RShift+") }
            if m & 0x40 != 0 { parts.append("RAlt+") }
            if m & 0x80 != 0 { parts.append("RWin+") }
            return parts.joined()
        }
    }

    static func chord(_ m: UInt8, _ code: UInt8, host: Host = .mac) -> String {
        let prefix = mods(m, host: host)
        let name = key(code)
        return prefix.isEmpty ? name : prefix + name
    }
}

enum MacKey {
    /// Carbon virtual key code → HID keyboard usage.
    static let hidFromCG: [UInt16: UInt8] = [
        0x00: 0x04, 0x01: 0x16, 0x02: 0x07, 0x03: 0x09, 0x04: 0x0B, 0x05: 0x0A,
        0x06: 0x1D, 0x07: 0x1B, 0x08: 0x06, 0x09: 0x19, 0x0B: 0x05,
        0x0C: 0x14, 0x0D: 0x1A, 0x0E: 0x08, 0x0F: 0x15,
        0x10: 0x1C, 0x11: 0x17, 0x12: 0x1E, 0x13: 0x1F, 0x14: 0x20, 0x15: 0x21,
        0x16: 0x23, 0x17: 0x22, 0x18: 0x2E, 0x19: 0x26, 0x1A: 0x24, 0x1B: 0x2D,
        0x1C: 0x25, 0x1D: 0x27, 0x1E: 0x30, 0x1F: 0x12,
        0x20: 0x18, 0x21: 0x2F, 0x22: 0x0C, 0x23: 0x13, 0x24: 0x28, 0x25: 0x0F,
        0x26: 0x0D, 0x27: 0x34, 0x28: 0x0E, 0x29: 0x33, 0x2A: 0x31, 0x2B: 0x36,
        0x2C: 0x38, 0x2D: 0x11, 0x2E: 0x10, 0x2F: 0x37,
        0x30: 0x2B, 0x31: 0x2C, 0x32: 0x35, 0x33: 0x2A, 0x35: 0x29,
        0x39: 0x39,
        0x7A: 0x3A, 0x78: 0x3B, 0x63: 0x3C, 0x76: 0x3D, 0x60: 0x3E, 0x61: 0x3F,
        0x62: 0x40, 0x64: 0x41, 0x65: 0x42, 0x6D: 0x43, 0x67: 0x44, 0x6F: 0x45,
        0x71: 0x48, 0x72: 0x49, 0x73: 0x4A, 0x74: 0x4B, 0x75: 0x4C,
        0x77: 0x4D, 0x79: 0x4E,
        0x7B: 0x50, 0x7C: 0x4F, 0x7D: 0x51, 0x7E: 0x52,
    ]

    static func hid(from event: NSEvent) -> (mods: UInt8, code: UInt8)? {
        let flags = event.modifierFlags
        var mods: UInt8 = 0
        if flags.contains(.control) { mods |= 0x01 }
        if flags.contains(.shift) { mods |= 0x02 }
        if flags.contains(.option) { mods |= 0x04 }
        if flags.contains(.command) { mods |= 0x08 }

        let vk = UInt16(event.keyCode)
        // Ignore bare modifier key-downs
        let modifierVKs: Set<UInt16> = [0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E]
        if modifierVKs.contains(vk) { return nil }

        guard let code = hidFromCG[vk] else { return nil }
        return (mods, code)
    }
}

enum PadProtocol {
    static let reportID: UInt8 = 0x03
    static let reportSize = 65

    static func packet(_ bytes: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: reportSize)
        for (i, b) in bytes.prefix(reportSize).enumerated() { out[i] = b }
        return out
    }

    static func identify() -> [UInt8] { packet([reportID, 0xFB, 0xFB, 0xFB]) }

    static func readLayer(_ layer: UInt8) -> [UInt8] {
        packet([reportID, 0xFA, 0x0F, 0x03, layer, 0x05])
    }

    static func encode(_ binding: PadBinding, slot: UInt8, layer: UInt8) -> [UInt8] {
        var bytes: [UInt8] = [reportID, 0xFE, slot, layer]
        switch binding.kind {
        case .empty:
            bytes += [0x01, 0, 0, 0, 0, 0, 0x01, 0x00, 0x00]
        case .key:
            let steps = Array(binding.steps.prefix(18))
            bytes += [0x01, 0, 0, 0, 0, 0, UInt8(steps.count)]
            for step in steps {
                bytes += [step.mods, step.code]
            }
        case .media:
            let lo = UInt8(binding.media & 0xFF)
            let hi = UInt8((binding.media >> 8) & 0xFF)
            bytes += [0x02, 0, 0, 0, 0, 0, 0x00, lo, hi]
        case .mouse:
            switch binding.mouse {
            case .leftClick:
                bytes += [0x03, 0, 0, 0, 0, 0, 0x01, 0x00, 0x01]
            case .rightClick:
                bytes += [0x03, 0, 0, 0, 0, 0, 0x01, 0x00, 0x02]
            case .middleClick:
                bytes += [0x03, 0, 0, 0, 0, 0, 0x01, 0x00, 0x04]
            case .wheelUp:
                bytes += [0x03, 0, 0, 0, 0, 0, 0x03, 0, 0, 0, 0, 0x01]
            case .wheelDown:
                bytes += [0x03, 0, 0, 0, 0, 0, 0x03, 0, 0, 0, 0, 0xFF]
            }
        }
        return packet(bytes)
    }

    static let separator = packet([reportID, 0xAA, 0xAA])
    static let commit = packet([reportID, 0xFD, 0xFE, 0xFF])

    static func decode(_ data: Data) -> (slot: UInt8, layer: UInt8, binding: PadBinding)? {
        guard data.count > 12 else { return nil }
        let off = data[0] == reportID ? 1 : 0
        guard data[off] == 0xFA || data[off] == 0xFE else { return nil }
        let slot = data[off + 1]
        let layer = data[off + 2]
        let type = data[off + 3]
        let count = data[off + 9]
        let payload = data.dropFirst(off + 10)

        let binding: PadBinding
        switch type {
        case 1:
            var steps: [KeyStep] = []
            for i in 0..<Int(count) {
                let base = payload.startIndex + i * 2
                guard base + 1 < payload.endIndex else { break }
                let step = KeyStep(mods: payload[base], code: payload[base + 1])
                if step.mods == 0 && step.code == 0 { continue }
                steps.append(step)
            }
            binding = steps.isEmpty
                ? .empty
                : PadBinding(kind: .key, steps: steps, media: 0, mouse: .leftClick)
        case 2:
            guard payload.count >= 2 else { return nil }
            let usage = UInt16(payload[payload.startIndex]) | (UInt16(payload[payload.startIndex + 1]) << 8)
            binding = usage == 0 ? .empty : .media(usage)
        case 3, 4:
            let actionByte = payload.count > 0 ? payload[payload.startIndex] : 0
            let buttons = payload.count > 2 ? payload[payload.startIndex + 2] : 0
            let wheel = payload.count > 5 ? payload[payload.startIndex + 5] : 0
            let mouse: MouseAction
            if actionByte == 0x03 || actionByte == 0x04 || wheel != 0 {
                mouse = (wheel == 0xFF) ? .wheelDown : .wheelUp
            } else if buttons == 2 {
                mouse = .rightClick
            } else if buttons == 4 {
                mouse = .middleClick
            } else {
                mouse = .leftClick
            }
            binding = PadBinding(kind: .mouse, steps: [], media: 0, mouse: mouse)
        default:
            binding = .empty
        }
        return (slot, layer, binding)
    }

    static func control(for slot: UInt8) -> ControlID? {
        ControlID.allCases.first { $0.slot == slot }
    }
}
