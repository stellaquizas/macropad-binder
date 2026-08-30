import Foundation
import AppKit
import SwiftUI

enum BinderMode: String {
    case read, write
}

@MainActor
final class PadStore: ObservableObject {
    @Published var connected = false
    @Published var programmable = false
    @Published var link: PadLink = .none
    @Published var busy = false
    @Published var status = "Plug in the pad over USB or pair it over Bluetooth."
    @Published var errorMessage: String?
    @Published var layer = 0
    @Published var selected: ControlID = .key1
    @Published var mode: BinderMode = .read
    @Published var capturing = false
    @Published var profile = PadProfile.blank
    @Published var deviceProfile = PadProfile.blank
    @Published var confirmWrite = false
    @Published var batteryPercent: Int?
    @Published var liveHit: ControlID?
    /// Inferred from the last pad HID report. Nil until a unique match.
    @Published var liveLayer: Int?
    /// When the cached USB dump was last written. Nil if never saved.
    @Published var cacheSavedAt: Date?

    private let hid = HIDClient()
    private var pollTask: Task<Void, Never>?
    private var captureMonitor: Any?
    private var padEventMonitor: Any?
    private var padGlobalMonitor: Any?
    private var presenceMisses = 0
    private var lastPadHeard: Date?

    var dirty: Bool { profile != deviceProfile }

    /// Bluetooth cannot read firmware; the shown map is the last USB dump.
    var showingHistory: Bool { link == .bluetooth && !profile.isBlank }

    var historyCaption: String {
        if let at = cacheSavedAt {
            return "Last USB read \(at.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Last USB read — time unknown"
    }

    var selectedBinding: PadBinding {
        get { profile.layers[layer][selected] }
        set { profile.layers[layer][selected] = newValue }
    }

    var diffs: [BindingDiff] {
        var rows: [BindingDiff] = []
        for li in 0..<3 {
            for control in ControlID.allCases {
                let from = deviceProfile.layers[li][control]
                let to = profile.layers[li][control]
                if from != to {
                    rows.append(BindingDiff(layer: li + 1, control: control, from: from.dualLabel, to: to.dualLabel))
                }
            }
        }
        return rows
    }

    func start() {
        guard pollTask == nil else { return }
        loadCachedProfile()
        startPadEventMonitor()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshPresence()
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        hid.stopSniff()
        endCapture()
        if let monitor = padEventMonitor {
            NSEvent.removeMonitor(monitor)
            padEventMonitor = nil
        }
        if let monitor = padGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            padGlobalMonitor = nil
        }
    }

    func refreshPresence() async {
        let usb = hid.isProgrammable()
        let hidSeen = hid.isPresent()
        let heard = lastPadHeard.map { Date().timeIntervalSince($0) < 90 } ?? false
        let present = usb || hidSeen || heard
        let previous = link
        programmable = usb
        let next: PadLink = usb ? .usb : (present ? .bluetooth : .none)

        if present {
            presenceMisses = 0
            let becamePresent = !connected
            let linkChanged = previous != next
            connected = true
            link = next
            if usb {
                if becamePresent || (linkChanged && previous != .usb) {
                    status = "Pad connected over USB."
                    await readFromDevice()
                } else if !hid.isSniffing, !busy {
                    startSniff()
                }
            } else {
                enterBluetoothInspect(announce: becamePresent || linkChanged, restart: linkChanged)
            }
        } else {
            presenceMisses += 1
            if connected && presenceMisses >= 3 {
                connected = false
                programmable = false
                link = .none
                batteryPercent = nil
                hid.stopSniff()
                liveLayer = nil
                status = "Pad disconnected."
            }
        }
        if present, link == .bluetooth {
            batteryPercent = hid.bluetoothBatteryPercent()
        } else if link == .usb {
            batteryPercent = nil
        }
    }

    func readFromDevice() async {
        guard hid.isProgrammable() else {
            status = "Read/flash needs USB. Bluetooth is input-only."
            return
        }
        guard !busy else { return }
        busy = true
        errorMessage = nil
        status = "Reading…"
        await Task.yield()
        defer { busy = false }
        do {
            // HID callbacks ride the current run loop — stay on main.
            let loaded = try hid.readAll()
            profile = loaded
            deviceProfile = loaded
            saveCachedProfile()
            startSniff()
            mode = .read
            endCapture()
            status = "Read 3 layers. Press a pad key to inspect it."
        } catch {
            errorMessage = error.localizedDescription
            status = "Read failed."
        }
    }

    func setMode(_ next: BinderMode) {
        if next == .write, !programmable {
            status = "Write needs USB. Bluetooth is inspect-only (history map)."
            return
        }
        mode = next
        if next == .read {
            endCapture()
            status = link == .bluetooth ? bluetoothStatus : "Read mode. Press a pad key to inspect."
        } else {
            status = "Write mode. Capture or pick a preset, then flash the pad."
        }
    }

    func requestWrite() {
        guard hid.isProgrammable() else {
            status = "Read/flash needs USB. Bluetooth is input-only."
            return
        }
        guard mode == .write else { return }
        guard dirty else {
            status = "Nothing to write."
            return
        }
        confirmWrite = true
    }

    func writeToDevice() async {
        confirmWrite = false
        guard !busy else { return }
        busy = true
        errorMessage = nil
        status = "Writing…"
        await Task.yield()
        defer { busy = false }
        do {
            let count = try hid.write(profile: profile, original: deviceProfile)
            status = "Wrote \(count) slot\(count == 1 ? "" : "s"). Verifying…"
            await Task.yield()
            let loaded = try hid.readAll()
            profile = loaded
            deviceProfile = loaded
            saveCachedProfile()
            startSniff()
            mode = .read
            endCapture()
            status = "Wrote \(count) slot\(count == 1 ? "" : "s"). Verified."
        } catch {
            errorMessage = error.localizedDescription
            status = "Write failed."
        }
    }

    func revert() {
        profile = deviceProfile
        status = "Reverted to last read."
    }

    func apply(_ binding: PadBinding) {
        guard programmable, mode == .write else { return }
        profile.layers[layer][selected] = binding
    }

    func applyPreset(_ preset: PadPreset) {
        guard programmable, mode == .write else { return }
        if preset.layers.count >= 3 {
            profile.layers = Array(preset.layers.prefix(3))
            status = "Applied \(preset.title) to L1–L3. Write to flash the pad."
        } else if let only = preset.layers.first {
            profile.layers[layer] = only
            status = "Applied \(preset.title) to L\(layer + 1). Write to flash the pad."
        }
    }

    func clearSelected() {
        apply(.empty)
    }

    func beginCapture() {
        guard programmable, mode == .write else { return }
        capturing = true
        status = "Press a shortcut on the MacBook keyboard…"
        captureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // esc cancels capture
                Task { @MainActor in self.endCapture() }
                return nil
            }
            if let hid = MacKey.hid(from: event) {
                let padEvent = PadEvent.key(mods: hid.mods, code: hid.code)
                if self.matchesPadBinding(padEvent) {
                    return nil
                }
                Task { @MainActor in
                    self.apply(.key(hid.mods, hid.code))
                    self.endCapture()
                    self.status = "Bound \(self.selected.title) → \(self.selectedBinding.label)"
                }
                return nil
            }
            return event
        }
    }

    func endCapture() {
        if let captureMonitor {
            NSEvent.removeMonitor(captureMonitor)
        }
        captureMonitor = nil
        capturing = false
    }

    private func startSniff() {
        hid.startSniff { [weak self] event in
            Task { @MainActor in self?.notePadInput(event) }
        } physical: { [weak self] control in
            Task { @MainActor in self?.notePhysicalHit(control) }
        }
    }

    private func notePhysicalHit(_ control: ControlID) {
        lastPadHeard = Date()
        if !connected {
            connected = true
            programmable = hid.isProgrammable()
            link = programmable ? .usb : .bluetooth
        }
        selected = control
        flash(control)
        let history = link == .bluetooth ? " · history" : ""
        status = "Pad \(control.title)\(history)"
    }

    private func enterBluetoothInspect(announce: Bool, restart: Bool) {
        if mode == .write {
            mode = .read
            endCapture()
        }
        if restart {
            hid.stopSniff()
            startSniff()
        } else if !hid.isSniffing, !busy {
            startSniff()
        }
        if announce {
            status = bluetoothStatus
        }
    }

    private var bluetoothStatus: String {
        if profile.isBlank {
            return "Bluetooth · inspect only. No saved map — plug USB once to load bindings."
        }
        return "Bluetooth · \(historyCaption). Capture and write disabled."
    }

    /// HID reports fire even when the window is not key. Always count as a pad press.
    private func notePadInput(_ event: PadEvent) {
        lastPadHeard = Date()
        if !connected {
            connected = true
            programmable = hid.isProgrammable()
            link = programmable ? .usb : .bluetooth
        }
        inferLiveLayer(from: event)
    }

    /// Backup path: pad keystrokes land as normal NSEvents while this window is key.
    /// HID sniff can go silent after the first report; this keeps detection alive.
    private func startPadEventMonitor() {
        guard padEventMonitor == nil else { return }
        padEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard let chord = MacKey.hid(from: event) else { return event }
            let padEvent = PadEvent.key(mods: chord.mods, code: chord.code)
            let fromPad = self.matchesPadBinding(padEvent)
            if fromPad {
                if !self.capturing {
                    Task { @MainActor in self.inferLiveLayer(from: padEvent) }
                }
                return nil
            }
            return event
        }
        padGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let chord = MacKey.hid(from: event) else { return }
            let padEvent = PadEvent.key(mods: chord.mods, code: chord.code)
            guard self.matchesPadBinding(padEvent) else { return }
            Task { @MainActor in self.inferLiveLayer(from: padEvent) }
        }
    }

    private func matchesPadBinding(_ event: PadEvent) -> Bool {
        for li in 0..<3 {
            for control in ControlID.allCases {
                if deviceProfile.layers[li][control].matches(event)
                    || profile.layers[li][control].matches(event) {
                    return true
                }
            }
        }
        return false
    }

    private func inferLiveLayer(from event: PadEvent) {
        if capturing { return }

        var hits: [(Int, ControlID)] = []
        for li in 0..<3 {
            for control in ControlID.allCases {
                if deviceProfile.layers[li][control].matches(event)
                    || profile.layers[li][control].matches(event) {
                    hits.append((li, control))
                }
            }
        }
        lastPadHeard = Date()
        if !connected {
            connected = true
            programmable = hid.isProgrammable()
            link = programmable ? .usb : .bluetooth
        }
        guard !hits.isEmpty else {
            if link == .bluetooth {
                status = profile.isBlank
                    ? "Heard \(label(for: event)) from pad. Plug USB once to map it to a key."
                    : "Heard \(label(for: event)) — not in the saved map"
            }
            return
        }

        let layers = Set(hits.map(\.0))
        let controls = Set(hits.map(\.1))

        if layers.count == 1, let li = layers.first {
            liveLayer = li
            layer = li
        } else if !layers.contains(layer), let first = hits.first {
            layer = first.0
        }

        let control: ControlID
        if controls.count == 1, let only = controls.first {
            control = only
        } else if let onLayer = hits.first(where: { $0.0 == layer })?.1 {
            control = onLayer
        } else {
            control = hits[0].1
        }

        selected = control
        flash(control)

        let history = link == .bluetooth ? " · history" : ""
        if layers.count == 1 {
            status = "Pad is on L\(layer + 1) · \(control.title)\(history)"
        } else {
            let names = layers.sorted().map { "L\($0 + 1)" }.joined(separator: "/")
            status = "\(control.title) — \(names) share this binding\(history)"
        }
    }

    private func label(for event: PadEvent) -> String {
        switch event {
        case .key(let mods, let code): return HIDNames.chord(mods, code)
        case .media(let usage): return HIDNames.media(usage)
        case .mouse(let action): return action.label
        }
    }

    func flash(_ control: ControlID) {
        liveHit = control
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if liveHit == control { liveHit = nil }
        }
    }

    private var cacheURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacropadBinder", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("last-profile.json")
    }

    private func loadCachedProfile() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snap = try? decoder.decode(CachedPadSnapshot.self, from: data) {
            profile = snap.profile
            deviceProfile = snap.profile
            cacheSavedAt = snap.savedAt
            return
        }
        guard let loaded = try? decoder.decode(PadProfile.self, from: data) else { return }
        profile = loaded
        deviceProfile = loaded
        cacheSavedAt = (try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date)
    }

    private func saveCachedProfile() {
        cacheSavedAt = Date()
        let snap = CachedPadSnapshot(profile: deviceProfile, savedAt: cacheSavedAt ?? Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snap) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
