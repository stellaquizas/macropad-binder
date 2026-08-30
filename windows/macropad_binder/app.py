from __future__ import annotations

import copy
import threading
import tkinter as tk
from tkinter import messagebox
from typing import Optional

from pynput import keyboard

from . import catalog
from .hid_pad import PadHID
from .protocol import (
    ALT,
    CONTROLS,
    CTRL,
    GUI,
    SHIFT,
    TITLES,
    Binding,
    Layer,
    blank_profile,
)

BG = "#f5f5f7"
SURFACE = "#ffffff"
PLATE = "#e0e2e5"
ACCENT = "#eb5114"
TEXT = "#1f2124"
MUTED = "#6b6e74"
GOOD = "#1a9e5c"

VK_HID = {
    "a": 0x04, "b": 0x05, "c": 0x06, "d": 0x07, "e": 0x08, "f": 0x09,
    "g": 0x0A, "h": 0x0B, "i": 0x0C, "j": 0x0D, "k": 0x0E, "l": 0x0F,
    "m": 0x10, "n": 0x11, "o": 0x12, "p": 0x13, "q": 0x14, "r": 0x15,
    "s": 0x16, "t": 0x17, "u": 0x18, "v": 0x19, "w": 0x1A, "x": 0x1B,
    "y": 0x1C, "z": 0x1D,
    "1": 0x1E, "2": 0x1F, "3": 0x20, "4": 0x21, "5": 0x22,
    "6": 0x23, "7": 0x24, "8": 0x25, "9": 0x26, "0": 0x27,
    "-": 0x2D, "=": 0x2E, "[": 0x2F, "]": 0x30, "\\": 0x31,
    ";": 0x33, "'": 0x34, "`": 0x35, ",": 0x36, ".": 0x37, "/": 0x38,
}

SPECIAL_HID = {
    keyboard.Key.enter: 0x28,
    keyboard.Key.esc: 0x29,
    keyboard.Key.backspace: 0x2A,
    keyboard.Key.tab: 0x2B,
    keyboard.Key.space: 0x2C,
    keyboard.Key.delete: 0x4C,
    keyboard.Key.right: 0x4F,
    keyboard.Key.left: 0x50,
    keyboard.Key.down: 0x51,
    keyboard.Key.up: 0x52,
}


class BinderApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Macropad Binder")
        self.geometry("980x720")
        self.minsize(860, 600)
        self.configure(bg=BG)

        self.hid = PadHID()
        self.profile = blank_profile()
        self.device_profile = blank_profile()
        self.layer = 0
        self.selected = "key1"
        self.mode = "read"
        self.capturing = False
        self.busy = False
        self.connected = False
        self.status = "Plug in the pad over USB."
        self.capture_listener: Optional[keyboard.Listener] = None

        self._build()
        self.after(400, self._poll)

    def _build(self) -> None:
        header = tk.Frame(self, bg=SURFACE, padx=14, pady=10)
        header.pack(fill="x")
        self.status_var = tk.StringVar(value=self.status)
        tk.Label(header, text="Macropad Binder", font=("Segoe UI Semibold", 16), bg=SURFACE, fg=TEXT).pack(side="left")
        tk.Label(header, textvariable=self.status_var, font=("Segoe UI", 10), bg=SURFACE, fg=MUTED).pack(side="left", padx=16)

        self.conn_var = tk.StringVar(value="offline")
        tk.Label(header, textvariable=self.conn_var, font=("Consolas", 10), bg=SURFACE, fg=MUTED).pack(side="right")

        controls = tk.Frame(self, bg=SURFACE, padx=14, pady=(0, 10))
        controls.pack(fill="x")
        for i, name in enumerate(("L1", "L2", "L3")):
            b = tk.Button(controls, text=name, width=4, command=lambda n=i: self._set_layer(n), relief="flat")
            b.pack(side="left", padx=2)
            setattr(self, f"layer_btn_{i}", b)

        tk.Frame(controls, width=12, bg=SURFACE).pack(side="left")
        self.read_btn = tk.Button(controls, text="Read", width=7, command=lambda: self._set_mode("read"), relief="flat")
        self.write_btn = tk.Button(controls, text="Write", width=7, command=lambda: self._set_mode("write"), relief="flat")
        self.read_btn.pack(side="left", padx=2)
        self.write_btn.pack(side="left", padx=2)
        tk.Button(controls, text="Reload", command=self._reload).pack(side="left", padx=8)
        self.flash_btn = tk.Button(controls, text="Flash pad", command=self._flash, state="disabled")
        self.revert_btn = tk.Button(controls, text="Revert", command=self._revert, state="disabled")
        self.flash_btn.pack(side="right", padx=4)
        self.revert_btn.pack(side="right", padx=4)

        body = tk.Frame(self, bg=BG)
        body.pack(fill="both", expand=True, padx=12, pady=12)

        self.canvas = tk.Canvas(body, width=300, bg=PLATE, highlightthickness=0)
        self.canvas.pack(side="left", fill="y", padx=(0, 12))
        self.canvas.bind("<Button-1>", self._on_canvas)

        right = tk.Frame(body, bg=SURFACE)
        right.pack(side="left", fill="both", expand=True)
        self.sel_var = tk.StringVar()
        self.chord_var = tk.StringVar()
        self.kit_var = tk.StringVar()
        self.guide_title = tk.StringVar()
        self.guide_body = tk.StringVar()
        tk.Label(right, textvariable=self.sel_var, font=("Segoe UI Semibold", 18), bg=SURFACE, fg=TEXT, anchor="w").pack(fill="x", padx=16, pady=(16, 0))
        tk.Label(right, textvariable=self.kit_var, font=("Consolas", 10), bg=SURFACE, fg=MUTED, anchor="w").pack(fill="x", padx=16)
        tk.Label(right, textvariable=self.chord_var, font=("Segoe UI Semibold", 22), bg=SURFACE, fg=TEXT, anchor="w").pack(fill="x", padx=16, pady=(8, 0))
        tk.Label(right, textvariable=self.guide_title, font=("Segoe UI Semibold", 14), bg=SURFACE, fg=ACCENT, anchor="w").pack(fill="x", padx=16, pady=(12, 0))
        tk.Label(right, textvariable=self.guide_body, font=("Segoe UI", 11), bg=SURFACE, fg=TEXT, wraplength=520, justify="left", anchor="w").pack(fill="x", padx=16, pady=(4, 8))

        self.sheet = tk.Text(right, height=8, font=("Consolas", 10), bg="#f0f1f3", relief="flat", wrap="none")
        self.sheet.pack(fill="x", padx=16, pady=8)
        self.sheet.configure(state="disabled")

        self.edit_frame = tk.Frame(right, bg=SURFACE)
        self.edit_frame.pack(fill="x", padx=16, pady=8)
        tk.Button(self.edit_frame, text="Capture shortcut", command=self._toggle_capture).pack(side="left")
        tk.Button(self.edit_frame, text="Clear", command=self._clear).pack(side="left", padx=8)
        preset_row = tk.Frame(right, bg=SURFACE)
        preset_row.pack(fill="x", padx=16, pady=(0, 12))
        tk.Label(preset_row, text="Presets", font=("Segoe UI", 9), bg=SURFACE, fg=MUTED).pack(side="left", padx=(0, 8))
        for title, _target in catalog.PRESETS:
            tk.Button(preset_row, text=title, command=lambda t=title: self._preset(t)).pack(side="left", padx=3)
        self.preset_row = preset_row

        self._refresh()

    def dirty(self) -> bool:
        return self.profile != self.device_profile

    def _set_layer(self, i: int) -> None:
        self.layer = i
        self._refresh()

    def _set_mode(self, mode: str) -> None:
        self.mode = mode
        if mode == "read":
            self._stop_capture()
            self.status = "Read mode. Press a pad key or click a control to inspect."
        else:
            self.status = "Write mode. Capture a Windows shortcut, then Flash pad."
        self._refresh()

    def _poll(self) -> None:
        present = self.hid.is_present()
        if present and not self.connected and not self.busy:
            self.connected = True
            self._reload()
        elif not present and self.connected:
            self.connected = False
            self.hid.close()
            self.status = "Pad disconnected."
            self._refresh()
        self.after(1200, self._poll)

    def _reload(self) -> None:
        if self.busy:
            return
        self.busy = True
        self.status = "Reading…"
        self._refresh()

        def work() -> None:
            try:
                loaded = self.hid.read_all()
                self.after(0, lambda: self._loaded(loaded))
            except Exception as exc:
                self.after(0, lambda: self._fail(str(exc)))

        threading.Thread(target=work, daemon=True).start()

    def _loaded(self, loaded: list[Layer]) -> None:
        self.profile = loaded
        self.device_profile = copy.deepcopy(loaded)
        self.busy = False
        self.connected = True
        self.mode = "read"
        self.status = "Read 3 layers. Press a pad key or click a control to inspect."
        self._refresh()

    def _fail(self, msg: str) -> None:
        self.busy = False
        self.status = msg
        self._refresh()
        messagebox.showerror("Pad", msg)

    def _flash(self) -> None:
        if self.mode != "write" or not self.dirty() or self.busy:
            return
        diffs = []
        for li in range(3):
            for c in CONTROLS:
                a, b = self.device_profile[li][c], self.profile[li][c]
                if a != b:
                    diffs.append(f"L{li + 1} {TITLES[c]}: {a.win_label()} → {b.win_label()}")
        if not messagebox.askokcancel("Write to pad?", "\n".join(diffs) or "No diffs"):
            return
        self.busy = True
        self.status = "Writing…"
        self._refresh()
        profile = copy.deepcopy(self.profile)
        original = copy.deepcopy(self.device_profile)

        def work() -> None:
            try:
                n = self.hid.write(profile, original)
                loaded = self.hid.read_all()
                self.after(0, lambda: self._wrote(n, loaded))
            except Exception as exc:
                self.after(0, lambda: self._fail(str(exc)))

        threading.Thread(target=work, daemon=True).start()

    def _wrote(self, n: int, loaded: list[Layer]) -> None:
        self.profile = loaded
        self.device_profile = copy.deepcopy(loaded)
        self.busy = False
        self.mode = "read"
        self.status = f"Wrote {n} slot{'s' if n != 1 else ''}. Verified."
        self._refresh()

    def _revert(self) -> None:
        self.profile = copy.deepcopy(self.device_profile)
        self.status = "Reverted to last read."
        self._refresh()

    def _clear(self) -> None:
        if self.mode != "write":
            return
        self.profile[self.layer][self.selected] = Binding.empty()
        self._refresh()

    def _preset(self, title: str) -> None:
        if self.mode != "write":
            return
        if title == "Vibe kit":
            self.profile = [
                copy.deepcopy(catalog.CURSOR_MAC),
                copy.deepcopy(catalog.CHATGPT_MAC),
                copy.deepcopy(catalog.CURSOR_WIN),
            ]
            self.status = "Applied Vibe kit to L1–L3. Flash to write."
            self._refresh()
            return
        layer = dict(catalog.PRESETS).get(title)
        if isinstance(layer, dict):
            self.profile[self.layer] = copy.deepcopy(layer)
            self.status = f"Applied {title} to L{self.layer + 1}."
        self._refresh()

    def _toggle_capture(self) -> None:
        if self.mode != "write":
            return
        if self.capturing:
            self._stop_capture()
            self.status = "Capture cancelled."
            self._refresh()
            return
        self.capturing = True
        self.status = "Listening… press a shortcut on this PC’s keyboard. Esc cancels."
        self._refresh()
        self.capture_listener = keyboard.Listener(on_press=self._on_cap)
        self.capture_listener.start()

    def _stop_capture(self) -> None:
        self.capturing = False
        if self.capture_listener is not None:
            try:
                self.capture_listener.stop()
            except Exception:
                pass
            self.capture_listener = None

    def _on_cap(self, key: keyboard.Key | keyboard.KeyCode) -> None:
        if not self.capturing:
            return
        if key == keyboard.Key.esc:
            self.after(0, lambda: (self._stop_capture(), setattr(self, "status", "Capture cancelled."), self._refresh()))
            return
        if key in (keyboard.Key.ctrl, keyboard.Key.ctrl_l, keyboard.Key.ctrl_r,
                   keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r,
                   keyboard.Key.alt, keyboard.Key.alt_l, keyboard.Key.alt_gr,
                   keyboard.Key.cmd, keyboard.Key.cmd_l, keyboard.Key.cmd_r):
            return
        hid_code = SPECIAL_HID.get(key)
        if hid_code is None and hasattr(key, "char") and key.char:
            hid_code = VK_HID.get(key.char.lower())
        if hid_code is None:
            return
        import ctypes
        mods = 0
        GetAsyncKeyState = ctypes.windll.user32.GetAsyncKeyState
        if GetAsyncKeyState(0x11) & 0x8000:
            mods |= CTRL
        if GetAsyncKeyState(0x10) & 0x8000:
            mods |= SHIFT
        if GetAsyncKeyState(0x12) & 0x8000:
            mods |= ALT
        if (GetAsyncKeyState(0x5B) & 0x8000) or (GetAsyncKeyState(0x5C) & 0x8000):
            mods |= GUI
        binding = Binding.key(mods, hid_code)
        self.after(0, lambda: self._captured(binding))

    def _captured(self, binding: Binding) -> None:
        self._stop_capture()
        if self.mode != "write":
            return
        self.profile[self.layer][self.selected] = binding
        self.status = f"Bound {TITLES[self.selected]} → {binding.win_label()}"
        self._refresh()

    def _hit_boxes(self) -> list[tuple[str, int, int, int, int]]:
        # x0,y0,x1,y1 in canvas coords
        w = int(self.canvas.winfo_width() or 300)
        cx = w // 2
        return [
            ("knobCCW", 8, 40, cx - 48, 200),
            ("knobPress", cx - 46, 70, cx + 46, 162),
            ("knobCW", cx + 48, 40, w - 8, 200),
            ("key1", cx - 70, 220, cx + 70, 360),
            ("key2", cx - 70, 372, cx + 70, 512),
            ("key3", cx - 70, 524, cx + 70, 664),
        ]

    def _on_canvas(self, event: tk.Event) -> None:  # type: ignore[type-arg]
        for name, x0, y0, x1, y1 in self._hit_boxes():
            if x0 <= event.x <= x1 and y0 <= event.y <= y1:
                self.selected = name
                self._refresh()
                return

    def _refresh(self) -> None:
        self.status_var.set(self.status)
        self.conn_var.set("1189:8840 · online" if self.connected else "offline")
        for i in range(3):
            btn: tk.Button = getattr(self, f"layer_btn_{i}")
            on = self.layer == i
            btn.configure(bg=ACCENT if on else PLATE, fg="white" if on else TEXT)
        self.read_btn.configure(bg=ACCENT if self.mode == "read" else PLATE, fg="white" if self.mode == "read" else TEXT)
        self.write_btn.configure(bg=ACCENT if self.mode == "write" else PLATE, fg="white" if self.mode == "write" else TEXT)
        dirty = self.dirty() and self.mode == "write" and self.connected and not self.busy
        self.flash_btn.configure(state="normal" if dirty else "disabled")
        self.revert_btn.configure(state="normal" if self.dirty() and self.mode == "write" else "disabled")
        for child in self.edit_frame.winfo_children():
            child.configure(state="normal" if self.mode == "write" and not self.busy else "disabled")
        for child in self.preset_row.winfo_children():
            if isinstance(child, tk.Button):
                child.configure(state="normal" if self.mode == "write" and not self.busy else "disabled")

        layer = self.profile[self.layer]
        binding = layer[self.selected]
        kit, hint = catalog.detect(layer)
        app, title, how = catalog.guide(binding)
        self.sel_var.set(TITLES[self.selected])
        self.kit_var.set(f"Layer {self.layer + 1} · {kit}" + ("  ·  capturing" if self.capturing else ""))
        self.chord_var.set(binding.win_label())
        self.guide_title.set((" · ".join(x for x in (app, title) if x)) or title)
        self.guide_body.set(how if self.mode == "write" or True else hint)

        self.sheet.configure(state="normal")
        self.sheet.delete("1.0", "end")
        self.sheet.insert("end", f"{hint}\n\n")
        for c in CONTROLS:
            g = catalog.guide(layer[c])
            mark = ">" if c == self.selected else " "
            self.sheet.insert("end", f"{mark} {TITLES[c]:<16} {layer[c].win_label():<18} {g[1]}\n")
        self.sheet.configure(state="disabled")
        self._draw_pad()

    def _draw_pad(self) -> None:
        c = self.canvas
        c.delete("all")
        w = int(c.winfo_width() or 300)
        h = int(c.winfo_height() or 640)
        c.create_rectangle(0, 0, w, h, fill=PLATE, outline="")
        layer = self.profile[self.layer]
        cx, cy, r = w // 2, 116, 64
        c.create_oval(cx - r, cy - r, cx + r, cy + r, fill="#c8cace", outline="#bbb")
        press = layer["knobPress"]
        on = self.selected == "knobPress"
        c.create_oval(cx - 36, cy - 36, cx + 36, cy + 36, fill="#fff4ee" if on else SURFACE, outline=ACCENT if on else "#ccc", width=2)
        c.create_text(cx, cy - 8, text="Click", fill=MUTED, font=("Segoe UI", 9, "bold"))
        c.create_text(cx, cy + 10, text=press.win_label(), fill=TEXT, font=("Segoe UI Semibold", 10))
        ccw, cw = layer["knobCCW"], layer["knobCW"]
        c.create_text(cx - 118, cy - 10, text="↺  " + ccw.win_label(), fill=ACCENT if self.selected == "knobCCW" else MUTED, font=("Segoe UI", 9, "bold"), anchor="e")
        c.create_text(cx - 118, cy + 8, text=catalog.guide(ccw)[1], fill=TEXT, font=("Segoe UI", 8), anchor="e")
        c.create_text(cx + 118, cy - 10, text=cw.win_label() + "  ↻", fill=ACCENT if self.selected == "knobCW" else MUTED, font=("Segoe UI", 9, "bold"), anchor="w")
        c.create_text(cx + 118, cy + 8, text=catalog.guide(cw)[1], fill=TEXT, font=("Segoe UI", 8), anchor="w")

        y = 220
        for name in ("key1", "key2", "key3"):
            b = layer[name]
            on = self.selected == name
            x0, y0, x1, y1 = cx - 70, y, cx + 70, y + 132
            c.create_rectangle(x0, y0, x1, y1, fill="#fff4ee" if on else SURFACE, outline=ACCENT if on else "#ccc", width=3 if on else 1)
            c.create_text(cx, y0 + 22, text=TITLES[name], fill=MUTED, font=("Segoe UI", 10, "bold"))
            c.create_text(cx, y0 + 58, text=b.win_label(), fill=TEXT, font=("Segoe UI Semibold", 14))
            c.create_text(cx, y0 + 88, text=catalog.guide(b)[1], fill=ACCENT, font=("Segoe UI", 10, "bold"))
            y += 152


def main() -> None:
    app = BinderApp()
    app.mainloop()
    app.hid.close()
