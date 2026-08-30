import Foundation
import IOKit.hid

enum HIDError: LocalizedError {
    case notFound
    case openFailed(IOReturn)
    case sendFailed(IOReturn)
    case timeout
    case unexpectedLayout(keys: Int, knobs: Int)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Pad not found. Plug it in over USB."
        case .openFailed(let rc): return String(format: "Could not open pad (%08x)", rc)
        case .sendFailed(let rc): return String(format: "HID write failed (%08x)", rc)
        case .timeout: return "Pad did not answer."
        case .unexpectedLayout(let k, let n): return "This firmware reports \(k) keys / \(n) knobs."
        }
    }
}

final class HIDClient {
    static let vendorID = 0x1189
    static let productID = 0x8840

    private var incoming: [Data] = []
    private var reportBuf = [UInt8](repeating: 0, count: 65)

    private func matchingVendor() -> [String: Any] {
        [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
            kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            kIOHIDPrimaryUsageKey as String: 1,
        ]
    }

    func isPresent() -> Bool {
        if isSniffing { return true }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, matchingVendor() as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        let found = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.isEmpty == false
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        return found
    }

    var isSniffing: Bool { sniffManager != nil && !sniffDevices.isEmpty }

    @discardableResult
    func withDevice<T>(_ body: (IOHIDDevice) throws -> T) throws -> T {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, matchingVendor() as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let device = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first else {
            throw HIDError.notFound
        }

        var rc = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if rc != kIOReturnSuccess {
            rc = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        guard rc == kIOReturnSuccess else { throw HIDError.openFailed(rc) }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        incoming.removeAll()
        IOHIDDeviceRegisterInputReportCallback(device, &reportBuf, reportBuf.count, { context, _, _, _, _, report, length in
            guard let context else { return }
            let client = Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue()
            client.incoming.append(Data(bytes: report, count: length))
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        defer {
            IOHIDDeviceRegisterInputReportCallback(device, &reportBuf, reportBuf.count, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        }

        return try body(device)
    }

    func send(_ device: IOHIDDevice, _ bytes: [UInt8]) throws {
        var payload = bytes
        if payload.count < 65 { payload += [UInt8](repeating: 0, count: 65 - payload.count) }
        let rc = payload.withUnsafeBufferPointer { buf in
            IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 3, buf.baseAddress!, 65)
        }
        if rc != kIOReturnSuccess { throw HIDError.sendFailed(rc) }
    }

    func pump(_ seconds: Double) {
        let until = Date().addingTimeInterval(seconds)
        while Date() < until {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
    }

    func takeIncoming() -> [Data] {
        let copy = incoming
        incoming.removeAll()
        return copy
    }

    func identify(_ device: IOHIDDevice) throws -> (keys: Int, knobs: Int) {
        incoming.removeAll()
        try send(device, PadProtocol.identify())
        pump(0.5)
        guard let reply = incoming.first, reply.count > 4 else { throw HIDError.timeout }
        let off = reply[0] == 0x03 ? 1 : 0
        return (Int(reply[off + 1]), Int(reply[off + 2]))
    }

    func readAll() throws -> PadProfile {
        try withDevice { device in
            let layout = try identify(device)
            if layout.keys != 3 || layout.knobs != 1 {
                throw HIDError.unexpectedLayout(keys: layout.keys, knobs: layout.knobs)
            }

            var profile = PadProfile.blank
            for layer in 1...3 {
                incoming.removeAll()
                try send(device, PadProtocol.readLayer(UInt8(layer)))
                pump(1.0)
                for packet in incoming {
                    guard let decoded = PadProtocol.decode(packet),
                          decoded.layer == UInt8(layer),
                          let control = PadProtocol.control(for: decoded.slot)
                    else { continue }
                    profile.layers[layer - 1][control] = decoded.binding
                }
            }
            return profile
        }
    }

    func write(profile: PadProfile, original: PadProfile) throws -> Int {
        var count = 0
        try withDevice { device in
            for layerIndex in 0..<3 {
                for control in ControlID.allCases {
                    let next = profile.layers[layerIndex][control]
                    let prev = original.layers[layerIndex][control]
                    guard next != prev else { continue }
                    try send(device, PadProtocol.encode(next, slot: control.slot, layer: UInt8(layerIndex + 1)))
                    pump(0.04)
                    try send(device, PadProtocol.separator)
                    pump(0.04)
                    try send(device, PadProtocol.commit)
                    pump(0.18)
                    try send(device, PadProtocol.separator)
                    pump(0.04)
                    count += 1
                }
            }
        }
        return count
    }

    private var sniffManager: IOHIDManager?
    private var sniffDevices: [IOHIDDevice] = []
    private var sniffBuf = [UInt8](repeating: 0, count: 32)
    private var sniffHandler: ((PadEvent) -> Void)?

    func startSniff(_ handler: @escaping (PadEvent) -> Void) {
        if isSniffing {
            sniffHandler = handler
            return
        }
        stopSniff()
        sniffHandler = handler
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
            kIOHIDPrimaryUsagePageKey as String: 1,
            kIOHIDPrimaryUsageKey as String: 6,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let client = Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue()
            client.attachSniffDevice(device)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        sniffManager = manager

        let devices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        for device in devices {
            attachSniffDevice(device)
        }
    }

    private func attachSniffDevice(_ device: IOHIDDevice) {
        if sniffDevices.contains(where: { $0 === device }) { return }
        let rc = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard rc == kIOReturnSuccess else { return }
        IOHIDDeviceRegisterInputReportCallback(device, &sniffBuf, sniffBuf.count, { context, _, _, _, reportID, report, length in
            guard let context else { return }
            let client = Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue()
            let data = Data(bytes: report, count: length)
            if let event = client.parseInput(reportID: reportID, data: data) {
                let handler = client.sniffHandler
                DispatchQueue.main.async { handler?(event) }
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        sniffDevices.append(device)
    }

    func stopSniff() {
        for device in sniffDevices {
            IOHIDDeviceRegisterInputReportCallback(device, &sniffBuf, sniffBuf.count, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        sniffDevices.removeAll()
        if let sniffManager {
            IOHIDManagerUnscheduleFromRunLoop(sniffManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(sniffManager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        sniffManager = nil
        sniffHandler = nil
    }

    fileprivate func parseInput(reportID: UInt32, data: Data) -> PadEvent? {
        var bytes = [UInt8](data)
        var id = UInt8(truncatingIfNeeded: reportID)
        if bytes.first == id, id != 0 {
            bytes.removeFirst()
        } else if reportID == 0, let first = bytes.first, [1, 2, 4, 5].contains(first) {
            id = first
            bytes.removeFirst()
        }
        switch id {
        case 1, 4:
            guard bytes.count >= 3 else { return nil }
            let mods = bytes[0]
            guard let code = bytes.dropFirst(2).first(where: { $0 != 0 }) else { return nil }
            return .key(mods: mods, code: code)
        case 5:
            guard bytes.count >= 2 else { return nil }
            let usage = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
            return usage == 0 ? nil : .media(usage)
        default:
            return nil
        }
    }
}
