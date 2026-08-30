# Windows

Python UI for the same pad and protocol as the macOS app. All three layers are equal; Mac and Windows presets both apply to whichever layer you have selected.

## Run

Python 3.10+ (`py` launcher or `python` on PATH).

```bat
cd windows
run.bat
```

```bat
py -3 -m pip install -r requirements.txt
py -3 -m macropad_binder
```

If `import hid` fails: install the Visual C++ redistributable, then `py -3 -m pip install --force-reinstall hidapi`.

## Use

1. Plug the pad in over USB.
2. App starts in **Read** and reads L1–L3.
3. Click a key/knob or press the pad to inspect (Mac and Win labels + guide).
4. Switch to **Write** to capture a shortcut from this PC, apply a preset, or clear a slot.
5. **Flash pad** writes only dirty slots. Review the diff first.

Presets: Cursor Mac, Cursor Win, ChatGPT Mac, ChatGPT Win (current layer), and Vibe kit (all three layers).

Cursor on Windows is **Ctrl+K / I / L**. Do not bind Win+K (Cast) or Win+L (lock).

Does not send bootloader (`0xEF`) or variant (`0xFC`) commands.
