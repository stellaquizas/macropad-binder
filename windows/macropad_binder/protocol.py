"""CH57x vendor HID protocol. Never send 0xEF (bootloader) or 0xFC (variant)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

VID = 0x1189
PID = 0x8840
REPORT_ID = 0x03
REPORT_SIZE = 65
FORBIDDEN = {0xEF, 0xFC}

CONTROLS = ("knobCCW", "knobPress", "knobCW", "key1", "key2", "key3")
SLOTS = {
    "key1": 3,
    "key2": 2,
    "key3": 1,
    "knobCCW": 16,
    "knobPress": 17,
    "knobCW": 18,
}
TITLES = {
    "key1": "Key 1",
    "key2": "Key 2",
    "key3": "Key 3",
    "knobCCW": "Anti-clockwise",
    "knobPress": "Knob click",
    "knobCW": "Clockwise",
}

KEYS = {
    0x04: "A", 0x05: "B", 0x06: "C", 0x07: "D", 0x08: "E", 0x09: "F",
    0x0A: "G", 0x0B: "H", 0x0C: "I", 0x0D: "J", 0x0E: "K", 0x0F: "L",
    0x10: "M", 0x11: "N", 0x12: "O", 0x13: "P", 0x14: "Q", 0x15: "R",
    0x16: "S", 0x17: "T", 0x18: "U", 0x19: "V", 0x1A: "W", 0x1B: "X",
    0x1C: "Y", 0x1D: "Z",
    0x1E: "1", 0x1F: "2", 0x20: "3", 0x21: "4", 0x22: "5", 0x23: "6",
    0x24: "7", 0x25: "8", 0x26: "9", 0x27: "0",
    0x28: "Enter", 0x29: "Esc", 0x2A: "Backspace", 0x2B: "Tab", 0x2C: "Space",
    0x2D: "-", 0x2E: "=", 0x2F: "[", 0x30: "]", 0x31: "\\",
    0x33: ";", 0x34: "'", 0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/",
    0x4C: "Del", 0x4F: "Right", 0x50: "Left", 0x51: "Down", 0x52: "Up",
}

CTRL, SHIFT, ALT, GUI = 0x01, 0x02, 0x04, 0x08


def packet(bytes_in: list[int]) -> list[int]:
    out = [0] * REPORT_SIZE
    for i, b in enumerate(bytes_in[:REPORT_SIZE]):
        out[i] = b
    return out


def identify() -> list[int]:
    return packet([REPORT_ID, 0xFB, 0xFB, 0xFB])


def read_layer(layer: int) -> list[int]:
    return packet([REPORT_ID, 0xFA, 0x0F, 0x03, layer, 0x05])


SEPARATOR = packet([REPORT_ID, 0xAA, 0xAA])
COMMIT = packet([REPORT_ID, 0xFD, 0xFE, 0xFF])


def assert_safe(payload: list[int]) -> None:
    cmd = payload[1] if len(payload) > 1 else 0
    if cmd in FORBIDDEN:
        raise RuntimeError(f"refusing forbidden command 0x{cmd:02X}")


@dataclass(frozen=True)
class Binding:
    kind: str = "empty"  # empty | key | media
    mods: int = 0
    code: int = 0
    media: int = 0

    @staticmethod
    def empty() -> "Binding":
        return Binding()

    @staticmethod
    def key(mods: int, code: int) -> "Binding":
        if mods == 0 and code == 0:
            return Binding.empty()
        return Binding(kind="key", mods=mods, code=code)

    def is_empty(self) -> bool:
        return self.kind == "empty" or (self.kind == "key" and self.mods == 0 and self.code == 0)

    def win_label(self) -> str:
        if self.is_empty():
            return "—"
        if self.kind == "media":
            return f"Media 0x{self.media:04X}"
        parts = []
        if self.mods & CTRL:
            parts.append("Ctrl+")
        if self.mods & SHIFT:
            parts.append("Shift+")
        if self.mods & ALT:
            parts.append("Alt+")
        if self.mods & GUI:
            parts.append("Win+")
        name = KEYS.get(self.code, f"0x{self.code:02X}")
        return "".join(parts) + name

    def mac_label(self) -> str:
        if self.is_empty():
            return "—"
        if self.kind == "media":
            return f"Media 0x{self.media:04X}"
        parts = []
        if self.mods & CTRL:
            parts.append("⌃")
        if self.mods & SHIFT:
            parts.append("⇧")
        if self.mods & ALT:
            parts.append("⌥")
        if self.mods & GUI:
            parts.append("⌘")
        name = KEYS.get(self.code, f"0x{self.code:02X}")
        return "".join(parts) + name

    def matches(self, mods: int, code: int) -> bool:
        return self.kind == "key" and self.mods == mods and self.code == code


Layer = dict[str, Binding]


def blank_layer() -> Layer:
    return {c: Binding.empty() for c in CONTROLS}


def blank_profile() -> list[Layer]:
    return [blank_layer() for _ in range(3)]


def encode(binding: Binding, slot: int, layer: int) -> list[int]:
    bytes_out = [REPORT_ID, 0xFE, slot, layer]
    if binding.is_empty():
        bytes_out += [0x01, 0, 0, 0, 0, 0, 0x01, 0x00, 0x00]
    elif binding.kind == "media":
        lo = binding.media & 0xFF
        hi = (binding.media >> 8) & 0xFF
        bytes_out += [0x02, 0, 0, 0, 0, 0, 0x00, lo, hi]
    else:
        bytes_out += [0x01, 0, 0, 0, 0, 0, 0x01, binding.mods, binding.code]
    return packet(bytes_out)


def decode(data: bytes) -> Optional[tuple[int, int, Binding]]:
    if len(data) < 13:
        return None
    off = 1 if data[0] == REPORT_ID else 0
    if data[off] not in (0xFA, 0xFE):
        return None
    slot = data[off + 1]
    layer = data[off + 2]
    typ = data[off + 3]
    count = data[off + 9]
    payload = data[off + 10 :]
    if typ == 1:
        mods = code = 0
        if count >= 1 and len(payload) >= 2:
            mods, code = payload[0], payload[1]
        binding = Binding.key(mods, code)
    elif typ == 2 and len(payload) >= 2:
        usage = payload[0] | (payload[1] << 8)
        binding = Binding(kind="media", media=usage) if usage else Binding.empty()
    else:
        binding = Binding.empty()
    return slot, layer, binding


def control_for_slot(slot: int) -> Optional[str]:
    for name, value in SLOTS.items():
        if value == slot:
            return name
    return None
