# Macropad Binder

Desktop UI for cheap 3-key + 1-knob USB pads that identify as **VID:PID `1189:8840`** (CH57x / “MINI_KEYBOARD” family). Read the three hardware layers, inspect bindings, capture a host shortcut, and write only the slots that changed.

macOS is a native SwiftUI app. Windows is a Python app. Same firmware protocol on both. Each layer can hold Mac chords (⌘ = GUI) or Windows chords (Ctrl / Alt / Win) — the pad does not store an OS profile, only HID.

```
swift/      macOS (SwiftUI)
windows/    Windows (Python)
```

## Safety

The firmware also accepts a bootloader jump (`0xEF`) and a variant command (`0xFC`). **This project never sends those.** Do not add them.

## Hardware

- USB composite device: vendor HID (usage page `0xFF00`, usage `1`) for programming, plus a keyboard interface for keystrokes
- 3 keys + 1 encoder (CCW / click / CW)
- 3 layers, switched by a **hardware** button on the case (LEDs flash). There is no USB “get/set current layer” command
- Firmware slots for the keys run from the end furthest from the knob. With the knob on the left, physical left → right is slots **3, 2, 1**. Knob CCW / press / CW are slots **16 / 17 / 18**
- One HID chord per slot: modifier bitmask + keycode. `0x08` is GUI (⌘ on Mac, Win on Windows)

## macOS

Requires macOS 14+ and Xcode command-line tools.

```bash
cd swift
./run.sh
```

Or: `cd swift && swift build -c release`, then run `.build/release/MacropadBinder`. The app is **not** sandboxed (needs HID).

- Default mode is **Read**. Pad presses select a control and show a guide; they do not rebind
- **Write** mode: capture from the laptop keyboard (`⌘K`), then flash (`⌘S`). Only dirty slots are sent
- Pad chords that match stored bindings are swallowed so they cannot trigger the app’s own shortcuts

## Windows

Python 3.10+.

```bat
cd windows
run.bat
```

Or:

```bat
py -3 -m pip install -r windows/requirements.txt
py -3 -m macropad_binder
```

Run that from the `windows` directory (so the `macropad_binder` package is importable). If `hidapi` fails to import, install the VC++ redistributable and `py -3 -m pip install --force-reinstall hidapi`.

Same Read / Write split. Capture uses this PC’s keyboard. GUI (`0x08`) is the Windows key — **Win+K is Cast**, not Cursor. Use Ctrl+K/I/L for Cursor on Windows.

## Presets

Any preset can be applied to **any** layer (or all three):

| Preset | Keys | Knob |
| --- | --- | --- |
| Cursor Mac | ⌘K / ⌘I / ⌘L | Esc / Enter / Tab |
| Cursor Win | Ctrl+K / Ctrl+I / Ctrl+L | Esc / Enter / Tab |
| ChatGPT Mac | ⌥Space / ⌘⇧O / ⌘K | Up / Enter / Down |
| ChatGPT Win | Alt+Space / Ctrl+Shift+O / Ctrl+K | Up / Enter / Down |
| Vibe kit | L1 Cursor Mac, L2 ChatGPT Mac, L3 Cursor Win | (as above) |

⌥Space and Alt+Space are the same HID. Vibe kit is one example split, not a requirement.

## Protocol (vendor HID)

65-byte reports, report ID `3`:

| Command | Bytes |
| --- | --- |
| Identify | `03 FB FB FB` → key count, knob count |
| Read layer *n* | `03 FA 0F 03 n 05` |
| Write slot | `03 FE <slot> <layer> …` then `AA AA`, `FD FE FF`, `AA AA` |

## License

MIT. See [LICENSE](LICENSE).
