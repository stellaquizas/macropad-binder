import Foundation
import AppKit
import SwiftUI

enum BinderMode: String {
    case read, write
}

@MainActor
final class PadStore: ObservableObject {
    @Published var connected = false
    @Published var busy = false
    @Published var status = "Plug in the pad over USB."
    @Published var errorMessage: String?
    @Published var layer = 0
    @Published var selected: ControlID = .key1
    @Published var mode: BinderMode = .read
    @Published var capturing = false
    @Published var profile = PadProfile.blank
    @Published var deviceProfile = PadProfile.blank
    @Published var confirmWrite = false
    @Published var liveHit: ControlID?
    /// Inferred from the last pad HID report. Nil until a unique match.
    @Published var liveLayer: Int?

    private let hid = HIDClient()
    private var pollTask: Task<Void, Never>?
    private var captureMonitor: Any?
    private var padEventMonitor: Any?
    private var presenceMisses = 0

    var dirty: Bool { profile != deviceProfile }

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
    }

    func refreshPresence() async {
        let present = hid.isPresent()
        if present {
            presenceMisses = 0
            if !connected {
                connected = true
                status = "Pad connected."
                await readFromDevice()
            } else if !hid.isSniffing, !busy {
                startSniff()
            }
        } else {
            presenceMisses += 1
            if connected && presenceMisses >= 3 {
                connected = false
                hid.stopSniff()
                liveLayer = nil
                status = "Pad disconnected."
            }
        }
    }

    func readFromDevice() async {
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
        mode = next
        if next == .read {
            endCapture()
            status = "Read mode. Press a pad key to inspect."
        } else {
            status = "Write mode. Capture or pick a preset, then flash the pad."
        }
    }

    func requestWrite() {
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
        guard mode == .write else { return }
        profile.layers[layer][selected] = binding
    }

    func applyPreset(_ preset: PadPreset) {
        guard mode == .write else { return }
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
        guard mode == .write else { return }
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
            Task { @MainActor in self?.inferLiveLayer(from: event) }
        }
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
                // Eat pad chords so ⌘K / ⌘S on the pad cannot enter write/capture.
                return nil
            }
            return event
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
        guard !hits.isEmpty else { return }

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

        if layers.count == 1 {
            status = "Pad is on L\(layer + 1) · \(control.title)"
        } else {
            let names = layers.sorted().map { "L\($0 + 1)" }.joined(separator: "/")
            status = "\(control.title) — \(names) share this binding"
        }
    }

    func flash(_ control: ControlID) {
        liveHit = control
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            if liveHit == control { liveHit = nil }
        }
    }
}
