from __future__ import annotations

from .protocol import ALT, CTRL, GUI, SHIFT, Binding, Layer, blank_layer

GUIDES: dict[tuple[int, int], tuple[str, str, str]] = {
    (GUI, 0x0E): ("Cursor", "Inline Edit", "Select code in Cursor, press this key, type the change, Return to submit. Esc cancels. Mac default is ⌘K. On Windows this chord is Win+K (Cast) — use the Cursor Win preset (Ctrl+K) instead."),
    (GUI, 0x0C): ("Cursor", "Agent panel", "Toggles the Agent / AI sidepanel. Mac default is ⌘I. On Windows the Win key is GUI — use Ctrl+I on a Windows layer."),
    (GUI, 0x0F): ("Cursor", "Chat", "Toggles Chat. With code selected, starts a new chat. Mac default is ⌘L. On Windows use Ctrl+L (Win+L locks the PC)."),
    (GUI | SHIFT, 0x0F): ("Cursor", "Add to Chat", "Select code, then press. Attaches the selection to the current chat (⌘⇧L / Ctrl+Shift+L)."),
    (GUI, 0x08): ("Cursor", "Agent layout", "Toggles Agent layout (⌘E)."),
    (GUI, 0x37): ("Cursor", "Mode menu", "Opens Agent / Ask / Plan / Debug (⌘.)."),
    (GUI | SHIFT, 0x13): ("Cursor", "Command Palette", "Palette (⌘⇧P). Type a command, Return."),
    (GUI, 0x13): ("Cursor", "Quick Open", "Fuzzy-find a file (⌘P)."),
    (GUI | SHIFT, 0x2C): ("Cursor", "Voice Mode", "Toggle Cursor Voice Mode (⌘⇧Space)."),
    (CTRL, 0x0C): ("Cursor", "Agent panel", "Toggles the Agent / AI sidepanel (Ctrl+I). Press again to hide."),
    (CTRL, 0x0F): ("Cursor", "Chat", "Toggles Chat (Ctrl+L). With code selected, starts a new chat that already has the selection."),
    (CTRL | SHIFT, 0x0F): ("Cursor", "Add to Chat", "Select code, then press. Attaches the selection to the current chat (Ctrl+Shift+L)."),
    (CTRL | SHIFT, 0x0E): ("Cursor", "Add to Edit", "Select code, press — drops it into Inline Edit. Also delete-line in stock VS Code."),
    (CTRL, 0x08): ("Cursor", "Agent layout", "Toggles Agent layout (Ctrl+E)."),
    (CTRL, 0x37): ("Cursor", "Mode menu", "Opens Agent / Ask / Plan / Debug (Ctrl+.)."),
    (CTRL | SHIFT, 0x13): ("Cursor", "Command Palette", "Palette (Ctrl+Shift+P). Type a command, Enter."),
    (CTRL, 0x13): ("Cursor", "Quick Open", "Fuzzy-find a file (Ctrl+P)."),
    (CTRL | SHIFT, 0x2C): ("Cursor", "Voice Mode", "Toggle Cursor Voice Mode (Ctrl+Shift+Space)."),
    (CTRL | SHIFT, 0x0D): ("Cursor", "Cursor Settings", "Opens Cursor Settings (Ctrl+Shift+J)."),
    (CTRL, 0x28): ("Cursor", "Accept / Send", "Accept all diffs, or force-send in Chat (Ctrl+Enter)."),
    (SHIFT, 0x2B): ("Cursor", "Rotate Agent modes", "Shift+Tab cycles Agent / Ask / Plan / Debug. Plain Tab accepts autocomplete."),
    (0, 0x2B): ("Cursor", "Accept Tab", "Accept ghost autocomplete. In Chat: next message. Shift+Tab rotates Agent modes."),
    (0, 0x29): ("Cursor", "Escape", "Dismiss autocomplete, close palette, unfocus Chat."),
    (0, 0x28): ("Cursor", "Submit", "Submit Inline Edit / send Chat / accept dialog."),
    (0, 0x52): ("Cursor", "Up", "Previous palette item / last Chat prompt."),
    (0, 0x51): ("Cursor", "Down", "Next palette item / Chat history."),
    (ALT, 0x2C): ("ChatGPT", "Summon ChatGPT", "ChatGPT desktop companion (Alt+Space). Same HID as Mac ⌥Space."),
    (GUI | SHIFT, 0x12): ("ChatGPT", "New chat", "ChatGPT desktop: new chat (⌘⇧O)."),
    (CTRL | SHIFT, 0x12): ("ChatGPT", "New chat", "ChatGPT desktop: new chat (Ctrl+Shift+O)."),
    (CTRL, 0x0E): ("Cursor", "Inline Edit", "Select code in Cursor, press this key, type the change, Enter to submit. Esc cancels. This is Ctrl+K — never Win+K (that's Cast)."),
}

def guide(binding: Binding) -> tuple[str, str, str]:
    if binding.is_empty():
        return ("", "Empty", "Nothing is bound. Switch to Write and capture a shortcut.")
    if binding.kind != "key":
        return ("", binding.win_label(), "Sends this HID report.")
    hit = GUIDES.get((binding.mods, binding.code))
    if hit:
        return hit
    return ("", binding.win_label(), "Sends this chord. Meaning depends on the frontmost app.")


def _layer(pairs: dict[str, Binding]) -> Layer:
    layer = blank_layer()
    layer.update(pairs)
    return layer


CURSOR_WIN = _layer({
    "key1": Binding.key(CTRL, 0x0E),
    "key2": Binding.key(CTRL, 0x0C),
    "key3": Binding.key(CTRL, 0x0F),
    "knobCCW": Binding.key(0, 0x29),
    "knobPress": Binding.key(0, 0x28),
    "knobCW": Binding.key(0, 0x2B),
})

CHATGPT_WIN = _layer({
    "key1": Binding.key(ALT, 0x2C),
    "key2": Binding.key(CTRL | SHIFT, 0x12),
    "key3": Binding.key(CTRL, 0x0E),
    "knobCCW": Binding.key(0, 0x52),
    "knobPress": Binding.key(0, 0x28),
    "knobCW": Binding.key(0, 0x51),
})

CURSOR_MAC = _layer({
    "key1": Binding.key(GUI, 0x0E),
    "key2": Binding.key(GUI, 0x0C),
    "key3": Binding.key(GUI, 0x0F),
    "knobCCW": Binding.key(0, 0x29),
    "knobPress": Binding.key(0, 0x28),
    "knobCW": Binding.key(0, 0x2B),
})

CHATGPT_MAC = _layer({
    "key1": Binding.key(ALT, 0x2C),
    "key2": Binding.key(GUI | SHIFT, 0x12),
    "key3": Binding.key(GUI, 0x0E),
    "knobCCW": Binding.key(0, 0x52),
    "knobPress": Binding.key(0, 0x28),
    "knobCW": Binding.key(0, 0x51),
})

PRESETS = [
    ("Cursor Mac", CURSOR_MAC),
    ("Cursor Win", CURSOR_WIN),
    ("ChatGPT Mac", CHATGPT_MAC),
    ("ChatGPT Win", CHATGPT_WIN),
    ("Vibe kit", None),
]


def detect(layer: Layer) -> tuple[str, str]:
    def score(preset: Layer) -> int:
        return sum(1 for k in layer if (not layer[k].is_empty()) and layer[k] == preset[k])

    ranked = [
        ("Cursor Win", score(CURSOR_WIN), "This layer matches Cursor on Windows (Ctrl chords)."),
        ("ChatGPT Win", score(CHATGPT_WIN), "This layer matches ChatGPT desktop on Windows."),
        ("Cursor Mac", score(CURSOR_MAC), "This layer matches Cursor on Mac (⌘ chords). On Windows, GUI is the Win key."),
        ("ChatGPT Mac", score(CHATGPT_MAC), "This layer matches ChatGPT desktop on Mac. Alt+Space is the same HID as Windows."),
    ]
    name, n, hint = max(ranked, key=lambda x: x[1])
    if n >= 3:
        return name, hint
    return "Custom", "No stock kit matched. Guides below are from each chord."
