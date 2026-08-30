import SwiftUI

enum Theme {
    static let bg = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let surface = Color.white
    static let raised = Color(red: 0.93, green: 0.94, blue: 0.95)
    static let plate = Color(red: 0.88, green: 0.89, blue: 0.91)
    static let keycap = Color.white
    static let keycapTop = Color(red: 1.0, green: 0.96, blue: 0.93)
    static let knobMetal = Color(red: 0.78, green: 0.79, blue: 0.82)
    static let knobFace = Color(red: 0.94, green: 0.94, blue: 0.95)
    static let line = Color.black.opacity(0.10)
    static let text = Color(red: 0.12, green: 0.13, blue: 0.15)
    static let muted = Color(red: 0.42, green: 0.44, blue: 0.48)
    static let accent = Color(red: 0.92, green: 0.32, blue: 0.14)
    static let good = Color(red: 0.10, green: 0.62, blue: 0.36)
    static let warn = Color(red: 0.85, green: 0.55, blue: 0.08)
}

struct PadMetrics {
    let knob: CGFloat
    let key: CGFloat
    let press: CGFloat
    let gap: CGFloat
    let type: CGFloat
    let compact: Bool

    static func fit(_ size: CGSize) -> PadMetrics {
        let padH = max(size.height - 20, 240)
        let padW = max(size.width - 16, 220)
        let gap = max(6, min(10, padH * 0.012))
        let knob = min(
            168,
            (padH - gap * 4) / 3.85,
            padW * (padW < 360 ? 0.42 : 0.36)
        )
        let key = min(knob * 0.92, padW - 28, 156)
        return PadMetrics(
            knob: knob,
            key: key,
            press: knob * 0.44,
            gap: gap,
            type: max(12, key * 0.13),
            compact: padW < 400
        )
    }
}

struct OSPair: View {
    let binding: PadBinding
    var compact: Bool = false

    var body: some View {
        let meaning = ShortcutCatalog.meaning(for: binding)
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            row("Mac", binding.macLabel, meaning.mac)
            row("Win", binding.winLabel, meaning.win)
        }
    }

    private func row(_ os: String, _ chord: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(os)
                    .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, alignment: .leading)
                Text(chord)
                    .font(.system(size: compact ? 18 : 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(desc)
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 44)
        }
    }
}

struct ChordLegend: View {
    let binding: PadBinding
    var align: HorizontalAlignment = .center
    var size: CGFloat = 16

    var body: some View {
        let guide = ShortcutCatalog.guide(for: binding)
        return VStack(alignment: align, spacing: 2) {
            Text(binding.macLabel)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
            if !binding.isEmpty {
                Text(guide.title)
                    .font(.system(size: max(10, size - 4), weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            if binding.winLabel != binding.macLabel {
                Text(binding.winLabel)
                    .font(.system(size: max(10, size - 3), weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.55)
    }
}

struct SquareKey: View {
    let title: String
    let binding: PadBinding
    let selected: Bool
    let flashing: Bool
    let dirty: Bool
    let metrics: PadMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: metrics.key * 0.05) {
                Text(title)
                    .font(.system(size: max(11, metrics.type * 0.85), weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                ChordLegend(binding: binding, size: metrics.type)
            }
            .padding(metrics.key * 0.08)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: max(10, metrics.key * 0.1), style: .continuous)
                    .fill(flashing ? Theme.accent.opacity(0.16) : (selected ? Theme.keycapTop : Theme.keycap))
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(10, metrics.key * 0.1), style: .continuous)
                    .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2.5 : 1)
            )
            .shadow(color: Color.black.opacity(0.07), radius: 4, y: 1)
            .overlay(alignment: .topTrailing) {
                if dirty {
                    Circle()
                        .fill(Theme.warn)
                        .frame(width: 8, height: 8)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct KnobControl: View {
    let ccw: PadBinding
    let press: PadBinding
    let cw: PadBinding
    let selected: ControlID?
    let flashing: ControlID?
    let dirtyCCW: Bool
    let dirtyPress: Bool
    let dirtyCW: Bool
    let metrics: PadMetrics
    let onSelect: (ControlID) -> Void

    private var knobSize: CGFloat { metrics.knob }
    private var pressSize: CGFloat { metrics.press }

    var body: some View {
        HStack(alignment: .center, spacing: metrics.compact ? 6 : 10) {
            sideLabel(
                id: .knobCCW,
                glyph: "↺",
                title: "Anti-clockwise",
                binding: ccw,
                dirty: dirtyCCW,
                alignment: .trailing
            )

            ZStack {
                knobBody
                ringHitTargets
                pressButton
            }
            .frame(width: knobSize, height: knobSize)

            sideLabel(
                id: .knobCW,
                glyph: "↻",
                title: "Clockwise",
                binding: cw,
                dirty: dirtyCW,
                alignment: .leading
            )
        }
    }

    private var knobBody: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.knobFace, Theme.knobMetal],
                        center: .center,
                        startRadius: knobSize * 0.1,
                        endRadius: knobSize / 2
                    )
                )
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 2)

            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: max(2, knobSize * 0.014), height: max(6, knobSize * 0.055))
                    .offset(y: -(knobSize / 2) + knobSize * 0.05)
                    .rotationEffect(.degrees(Double(i) * 15))
            }

            Circle()
                .stroke(Theme.line, lineWidth: 1.5)
                .padding(knobSize * 0.1)

            if flashing == .knobCCW || selected == .knobCCW {
                arcHighlight(id: .knobCCW)
            }
            if flashing == .knobCW || selected == .knobCW {
                arcHighlight(id: .knobCW)
            }
        }
    }

    private func arcHighlight(id: ControlID) -> some View {
        let hit = flashing == id
        let color = hit ? Theme.accent.opacity(0.85) : Theme.accent
        return Group {
            if id == .knobCCW {
                Circle()
                    .trim(from: 0.25, to: 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: max(4, knobSize * 0.03), lineCap: .butt))
            } else {
                Circle()
                    .trim(from: 0.75, to: 1)
                    .stroke(color, style: StrokeStyle(lineWidth: max(4, knobSize * 0.03), lineCap: .butt))
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(color, style: StrokeStyle(lineWidth: max(4, knobSize * 0.03), lineCap: .butt))
            }
        }
        .padding(2)
    }

    private var ringHitTargets: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.knobCCW) }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onSelect(.knobCW) }
        }
        .clipShape(Circle())
    }

    private var pressButton: some View {
        let on = selected == .knobPress
        let hit = flashing == .knobPress
        return Button { onSelect(.knobPress) } label: {
            VStack(spacing: 2) {
                Text("Click")
                    .font(.system(size: max(9, metrics.type * 0.7), weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.muted)
                ChordLegend(binding: press, size: max(11, metrics.type * 0.85))
            }
            .frame(width: pressSize, height: pressSize)
            .background(
                Circle().fill(hit ? Theme.accent.opacity(0.18) : (on ? Theme.keycapTop : Theme.keycap))
            )
            .overlay(
                Circle().stroke(on ? Theme.accent : Theme.line, lineWidth: on ? 2.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if dirtyPress {
                    Circle().fill(Theme.warn).frame(width: 7, height: 7).offset(x: -4, y: 4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sideLabel(
        id: ControlID,
        glyph: String,
        title: String,
        binding: PadBinding,
        dirty: Bool,
        alignment: HorizontalAlignment
    ) -> some View {
        let on = selected == id
        let hit = flashing == id
        return Button { onSelect(id) } label: {
            VStack(alignment: alignment, spacing: 4) {
                HStack(spacing: 4) {
                    if alignment == .trailing { Spacer(minLength: 0) }
                    Text(glyph)
                        .font(.system(size: metrics.compact ? 16 : 18, weight: .bold, design: .rounded))
                    if !metrics.compact {
                        Text(title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if dirty {
                        Circle().fill(Theme.warn).frame(width: 7, height: 7)
                    }
                    if alignment == .leading { Spacer(minLength: 0) }
                }
                .foregroundStyle(on ? Theme.accent : Theme.muted)
                ChordLegend(binding: binding, align: alignment, size: metrics.type)
            }
            .padding(metrics.compact ? 6 : 8)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hit ? Theme.accent.opacity(0.14) : (on ? Theme.keycapTop : Color.clear))
            )
        }
        .buttonStyle(.plain)
    }
}

struct PadFace: View {
    let layer: LayerProfile
    let original: LayerProfile
    let selected: ControlID
    let flashing: ControlID?
    let onSelect: (ControlID) -> Void

    var body: some View {
        GeometryReader { geo in
            let m = PadMetrics.fit(geo.size)
            VStack(spacing: m.gap + 4) {
                KnobControl(
                    ccw: layer[.knobCCW],
                    press: layer[.knobPress],
                    cw: layer[.knobCW],
                    selected: selected,
                    flashing: flashing,
                    dirtyCCW: layer[.knobCCW] != original[.knobCCW],
                    dirtyPress: layer[.knobPress] != original[.knobPress],
                    dirtyCW: layer[.knobCW] != original[.knobCW],
                    metrics: m,
                    onSelect: onSelect
                )

                VStack(spacing: m.gap) {
                    ForEach([ControlID.key1, .key2, .key3], id: \.self) { id in
                        SquareKey(
                            title: id.title,
                            binding: layer[id],
                            selected: selected == id,
                            flashing: flashing == id,
                            dirty: layer[id] != original[id],
                            metrics: m,
                            action: { onSelect(id) }
                        )
                        .frame(width: m.key, height: m.key)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.plate)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
        }
        .padding(10)
    }
}
