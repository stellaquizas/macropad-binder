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

enum PadLink {
    case none
    case usb
    case bluetooth
}

final class HIDClient {
    static let vendorID = 0x1189
    static let productID = 0x8840
    /// BLE HID identity (Apple-spoofed). USB programming uses vendorID/productID.
    static let bluetoothVendorID = 0x05AC
    static let bluetoothProductID = 0x022C
    static let bluetoothProduct = "MINI_KEYBOARD"

    private var incoming: [Data] = []
    private var reportBuf = [UInt8](repeating: 0, count: 65)
    private var batteryCache: (at: Date, value: Int?) = (.distantPast, nil)
    private var batteryRefreshing = false

    private func matchingVendor() -> [String: Any] {
        [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
            kIOHIDPrimaryUsagePageKey as String: 0xFF00,
            kIOHIDPrimaryUsageKey as String: 1,
        ]
    }

    private func matchingAnyInterface() -> [String: Any] {
        [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
        ]
    }

    private func matchingBluetoothPad() -> [String: Any] {
        [kIOHIDProductKey as String: Self.bluetoothProduct]
    }

    private func devices(matching: [String: Any]) -> [IOHIDDevice] {
        devices(matchingAny: [matching])
    }

    private func devices(matchingAny dicts: [[String: Any]]) -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, dicts as CFArray)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        return Array((IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? [])
    }

    private func padMatchers() -> [[String: Any]] {
        [
            matchingAnyInterface(),
            matchingBluetoothPad(),
            [
                kIOHIDVendorIDKey as String: NSNumber(value: Self.bluetoothVendorID),
                kIOHIDProductIDKey as String: NSNumber(value: Self.bluetoothProductID),
                kIOHIDProductKey as String: Self.bluetoothProduct,
            ],
        ]
    }

    private func transport(of device: IOHIDDevice) -> String {
        ((IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String) ?? "").lowercased()
    }

    private func intProp(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }

    private func stringProp(_ device: IOHIDDevice, _ key: String) -> String {
        (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
    }

    /// USB vendor pad (1189:8840) or the BLE clone named MINI_KEYBOARD.
    /// Matching dicts can accidentally bind every HID device — always filter here.
    func isPadDevice(_ device: IOHIDDevice) -> Bool {
        let product = stringProp(device, kIOHIDProductKey)
        if product.caseInsensitiveCompare(Self.bluetoothProduct) == .orderedSame { return true }
        let vid = intProp(device, kIOHIDVendorIDKey)
        let pid = intProp(device, kIOHIDProductIDKey)
        return vid == Self.vendorID && pid == Self.productID
    }

    /// Vendor programming interface — USB only on this firmware.
    func isProgrammable() -> Bool {
        !devices(matching: matchingVendor()).isEmpty
    }

    func isPresent() -> Bool {
        if !sniffDevices.isEmpty { return true }
        return devices(matchingAny: padMatchers()).contains(where: isPadDevice)
    }

    func currentLink() -> PadLink {
        if isProgrammable() { return .usb }
        let found = devices(matchingAny: padMatchers()).filter(isPadDevice)
        if found.contains(where: { transport(of: $0).contains("bluetooth") }) { return .bluetooth }
        if !found.isEmpty || !sniffDevices.isEmpty { return .bluetooth }
        return .none
    }

    /// Cached BLE battery from system_profiler. Nil on USB or if unknown.
    func bluetoothBatteryPercent() -> Int? {
        if Date().timeIntervalSince(batteryCache.at) < 20 {
            return batteryCache.value
        }
        if !batteryRefreshing {
            batteryRefreshing = true
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let value = Self.readProfilerBattery()
                DispatchQueue.main.async {
                    self?.batteryCache = (Date(), value)
                    self?.batteryRefreshing = false
                }
            }
        }
        return batteryCache.value
    }

    private static func readProfilerBattery() -> Int? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        proc.arguments = ["SPBluetoothDataType", "-json"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let root = (json["SPBluetoothDataType"] as? [[String: Any]])?.first,
            let connected = root["device_connected"] as? [[String: Any]]
        else { return nil }
        for wrapper in connected {
            for (name, raw) in wrapper {
                guard name.caseInsensitiveCompare(bluetoothProduct) == .orderedSame else { continue }
                guard let info = raw as? [String: Any] else { continue }
                let text = (info["device_batteryLevelMain"] as? String) ?? ""
                let digits = text.prefix(while: { $0.isNumber })
                return Int(digits)
            }
        }
        return nil
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
    private var sniffHandler: ((PadEvent) -> Void)?
    private var sniffPhysical: ((ControlID) -> Void)?
    private var sniffMods: UInt8 = 0
    private var lastChord: (PadEvent, Date)?
    private var lastPhysical: (ControlID, Date)?

    func startSniff(_ handler: @escaping (PadEvent) -> Void, physical: ((ControlID) -> Void)? = nil) {
        sniffHandler = handler
        sniffPhysical = physical
        if isSniffing { return }
        stopSniff()
        sniffHandler = handler
        sniffPhysical = physical
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, padMatchers() as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue().handleValue(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue().attachSniffDevice(device)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<HIDClient>.fromOpaque(context).takeUnretainedValue().detachSniffDevice(device)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        sniffManager = manager

        let found = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        for device in found {
            attachSniffDevice(device)
        }
    }

    private func attachSniffDevice(_ device: IOHIDDevice) {
        guard isPadDevice(device) else { return }
        if sniffDevices.contains(where: { $0 === device }) { return }
        _ = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        sniffDevices.append(device)
    }

    private func detachSniffDevice(_ device: IOHIDDevice) {
        guard let idx = sniffDevices.firstIndex(where: { $0 === device }) else { return }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        sniffDevices.remove(at: idx)
    }

    func stopSniff() {
        if let sniffManager {
            IOHIDManagerRegisterInputValueCallback(sniffManager, nil, nil)
            IOHIDManagerRegisterDeviceMatchingCallback(sniffManager, nil, nil)
            IOHIDManagerRegisterDeviceRemovalCallback(sniffManager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(sniffManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(sniffManager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        for device in sniffDevices {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        sniffDevices.removeAll()
        sniffManager = nil
        sniffHandler = nil
        sniffPhysical = nil
        sniffMods = 0
    }

    private func handleValue(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        guard isPadDevice(device) else { return }

        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let pressed = IOHIDValueGetIntegerValue(value)

        switch page {
        case 0x07:
            if usage >= 0xE0 && usage <= 0xE7 {
                let bit = UInt8(1 << (usage - 0xE0))
                if pressed != 0 { sniffMods |= bit } else { sniffMods &= ~bit }
                return
            }
            guard pressed != 0, usage >= 0x04, usage <= 0xA4 else { return }
            emitChord(.key(mods: sniffMods, code: UInt8(truncatingIfNeeded: usage)))
        case 0x0C:
            guard pressed != 0, usage != 0 else { return }
            emitChord(.media(UInt16(truncatingIfNeeded: usage)))
        case 0x09:
            guard pressed != 0 else { return }
            switch usage {
            case 1: emitPhysical(.key1)
            case 2: emitPhysical(.key2)
            case 3: emitPhysical(.key3)
            default: break
            }
        case 0x01:
            if usage == 0x38 {
                if pressed > 0 { emitPhysical(.knobCW) }
                else if pressed < 0 { emitPhysical(.knobCCW) }
            }
        default:
            break
        }
    }

    private func emitChord(_ event: PadEvent) {
        if let last = lastChord, last.0 == event, Date().timeIntervalSince(last.1) < 0.04 { return }
        lastChord = (event, Date())
        let handler = sniffHandler
        DispatchQueue.main.async { handler?(event) }
    }

    private func emitPhysical(_ control: ControlID) {
        if let last = lastPhysical, last.0 == control, Date().timeIntervalSince(last.1) < 0.05 { return }
        lastPhysical = (control, Date())
        let handler = sniffPhysical
        DispatchQueue.main.async { handler?(control) }
    }
}
