from __future__ import annotations

import time
from typing import Optional

import hid

from .protocol import (
    COMMIT,
    CONTROLS,
    PID,
    SEPARATOR,
    SLOTS,
    VID,
    Layer,
    assert_safe,
    blank_profile,
    control_for_slot,
    decode,
    encode,
    identify,
    read_layer,
)


class PadError(Exception):
    pass


class PadHID:
    def __init__(self) -> None:
        self.dev: Optional[hid.device] = None

    def close(self) -> None:
        if self.dev is not None:
            try:
                self.dev.close()
            except Exception:
                pass
            self.dev = None

    def is_present(self) -> bool:
        return bool(hid.enumerate(VID, PID))

    def _candidates(self) -> list[bytes]:
        preferred, others = [], []
        for info in hid.enumerate(VID, PID):
            path = info.get("path")
            if not path:
                continue
            up = info.get("usage_page") or 0
            usage = info.get("usage") or 0
            if up == 0xFF00 and usage == 1:
                preferred.append(path)
            elif up not in (0x01, 0x0C):
                others.append(path)
            else:
                others.append(path)
        # unique preserve order
        seen: set[bytes] = set()
        ordered = []
        for p in preferred + others:
            if p not in seen:
                seen.add(p)
                ordered.append(p)
        return ordered

    def _send(self, dev: hid.device, payload: list[int]) -> None:
        assert_safe(payload)
        n = dev.write(bytes(payload))
        if n < 0:
            raise PadError("HID write failed")

    def _read(self, dev: hid.device, timeout_ms: int) -> list[bytes]:
        packets: list[bytes] = []
        deadline = time.time() + timeout_ms / 1000
        while time.time() < deadline:
            remaining = max(1, int((deadline - time.time()) * 1000))
            data = dev.read(65, remaining)
            if data:
                packets.append(bytes(data))
        return packets

    def _identify(self, dev: hid.device) -> tuple[int, int]:
        self._send(dev, identify())
        packets = self._read(dev, 500)
        if not packets:
            raise PadError("Pad did not answer.")
        reply = packets[0]
        off = 1 if reply and reply[0] == 0x03 else 0
        if len(reply) < off + 3:
            raise PadError("Pad did not answer.")
        return reply[off + 1], reply[off + 2]

    def open(self) -> None:
        self.close()
        last = "Pad not found. Plug it in over USB."
        for path in self._candidates():
            d = hid.device() if hasattr(hid, "device") else hid.Device()
            try:
                d.open_path(path)
                d.set_nonblocking(False)
                keys, knobs = self._identify(d)
                if keys != 3 or knobs != 1:
                    d.close()
                    last = f"Unexpected layout {keys} keys / {knobs} knobs."
                    continue
                self.dev = d
                return
            except Exception as exc:
                last = str(exc)
                try:
                    d.close()
                except Exception:
                    pass
        raise PadError(last)

    def read_all(self) -> list[Layer]:
        if self.dev is None:
            self.open()
        assert self.dev is not None
        profile = blank_profile()
        for layer in range(1, 4):
            self._send(self.dev, read_layer(layer))
            packets = self._read(self.dev, 1000)
            for packet in packets:
                decoded = decode(packet)
                if not decoded:
                    continue
                slot, lyr, binding = decoded
                if lyr != layer:
                    continue
                control = control_for_slot(slot)
                if control:
                    profile[layer - 1][control] = binding
        return profile

    def write(self, profile: list[Layer], original: list[Layer]) -> int:
        if self.dev is None:
            self.open()
        assert self.dev is not None
        count = 0
        for li in range(3):
            for control in CONTROLS:
                nxt = profile[li][control]
                prev = original[li][control]
                if nxt == prev:
                    continue
                self._send(self.dev, encode(nxt, SLOTS[control], li + 1))
                time.sleep(0.04)
                self._send(self.dev, SEPARATOR)
                time.sleep(0.04)
                self._send(self.dev, COMMIT)
                time.sleep(0.18)
                self._send(self.dev, SEPARATOR)
                time.sleep(0.04)
                count += 1
        return count
