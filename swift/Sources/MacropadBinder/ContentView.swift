import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PadStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.line)
            GeometryReader { geo in
                let stacked = geo.size.width < 920
                if stacked {
                    VStack(spacing: 0) {
                        padGrid
                            .frame(minHeight: 280, idealHeight: geo.size.height * 0.58)
                        Divider().overlay(Theme.line)
                        EditorView()
                    }
                } else {
                    HStack(spacing: 0) {
                        padGrid
                            .frame(width: min(460, max(300, geo.size.width * 0.4)))
                        Divider().overlay(Theme.line)
                        EditorView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .background(Theme.bg)
        .frame(minWidth: 720, minHeight: 560)
        .onAppear { store.start() }
        .alert("Write to pad?", isPresented: $store.confirmWrite) {
            Button("Cancel", role: .cancel) {}
            Button("Write \(store.diffs.count) slots") {
                Task { await store.writeToDevice() }
            }
        } message: {
            Text(store.diffs.map { "L\($0.layer) \($0.control.title): \($0.from) → \($0.to)" }.joined(separator: "\n"))
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Macropad Binder")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text(store.status)
                    .font(.system(size: 12))
                    .foregroundStyle(store.errorMessage == nil ? Theme.muted : Theme.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Circle()
                    .fill(store.connected ? Theme.good : Theme.muted)
                    .frame(width: 8, height: 8)
                Text(store.connected
                     ? (store.liveLayer.map { "live L\($0 + 1)" } ?? "live ?")
                     : "offline")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.raised))

            layerPicker
            modePicker

            Button("Reload") { Task { await store.readFromDevice() } }
                .disabled(!store.connected || store.busy)
            if store.mode == .write {
                Button("Revert") { store.revert() }
                    .disabled(!store.dirty || store.busy)
                Button("Write") {
                    store.requestWrite()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!store.connected || !store.dirty || store.busy)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            modeTab(.read, "Read")
            modeTab(.write, "Write")
        }
        .background(Capsule().fill(Theme.raised))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }

    private func modeTab(_ mode: BinderMode, _ title: String) -> some View {
        Button {
            store.setMode(mode)
        } label: {
            Text(title)
        }
        .buttonStyle(.plain)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(store.mode == mode ? Color.white : Theme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(store.mode == mode ? Theme.accent : Color.clear)
    }

    private var layerPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Button {
                    store.layer = i
                } label: {
                    HStack(spacing: 5) {
                        if store.liveLayer == i {
                            Circle().fill(store.layer == i ? Color.white : Theme.good).frame(width: 6, height: 6)
                        }
                        Text("L\(i + 1)")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(store.layer == i ? Color.white : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(store.layer == i ? Theme.accent : Color.clear)
            }
        }
        .background(Capsule().fill(Theme.raised))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
    }

    private var padGrid: some View {
        let layer = store.profile.layers[store.layer]
        let original = store.deviceProfile.layers[store.layer]
        return PadFace(
            layer: layer,
            original: original,
            selected: store.selected,
            flashing: store.liveHit,
            onSelect: { store.selected = $0 }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

struct EditorView: View {
    @EnvironmentObject private var store: PadStore

    var body: some View {
        let binding = store.selectedBinding

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let kit = ShortcutCatalog.detect(store.profile.layers[store.layer])
                let guide = ShortcutCatalog.guide(for: binding)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selected.title)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.text)
                        Text(store.mode == .write ? "Editing layer \(store.layer + 1)" : "Layer \(store.layer + 1) · \(kit.title)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 12)
                    OSPair(binding: binding, compact: true)
                        .frame(maxWidth: 420, alignment: .leading)
                }

                BindingGuideCard(kit: kit, control: store.selected, binding: binding, guide: guide)

                if store.mode == .write {
                    HStack {
                        Button(store.capturing ? "Listening… laptop shortcut" : "Capture shortcut") {
                            store.capturing ? store.endCapture() : store.beginCapture()
                        }
                        .keyboardShortcut("k", modifiers: .command)
                        .tint(store.capturing ? Theme.warn : Theme.accent)
                        Button("Clear") { store.clearSelected() }
                        Spacer()
                        Text("⌘K  ·  ⌘S")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                    .controlSize(.regular)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.muted)
                        FlowPresets()
                        Text("Vibe kit: L1 Cursor Mac · L2 ChatGPT Mac · L3 Cursor Win")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    LayerCheatSheet(layer: store.profile.layers[store.layer])
                    Text("Read mode — pad presses only inspect. Switch to Write to rebind.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(18)
        }
        .background(Theme.surface)
    }
}

private struct BindingGuideCard: View {
    let kit: DetectedKit
    let control: ControlID
    let binding: PadBinding
    let guide: ChordGuide

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(kit.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(kit == .unknown ? Theme.muted : Theme.accent))
                if !guide.app.isEmpty {
                    Text(guide.app)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(kit.hint)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
            Text("\(control.title)  ·  \(guide.title)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(guide.how)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.raised)
        )
    }
}

private struct LayerCheatSheet: View {
    let layer: LayerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This layer")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.muted)
            ForEach([ControlID.knobCCW, .knobPress, .knobCW, .key1, .key2, .key3], id: \.self) { id in
                let b = layer[id]
                let g = ShortcutCatalog.guide(for: b)
                HStack(alignment: .firstTextBaseline) {
                    Text(id.title)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 110, alignment: .leading)
                    Text(b.macLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .frame(width: 72, alignment: .leading)
                    Text(g.title)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.raised.opacity(0.6))
        )
    }
}

private struct FlowPresets: View {
    @EnvironmentObject private var store: PadStore

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PadPreset.all) { preset in
                Button(preset.title) { store.applyPreset(preset) }
                    .help(preset.blurb)
            }
        }
        .controlSize(.regular)
    }
}
