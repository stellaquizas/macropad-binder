#!/usr/bin/env python3
"""Strip Cursor Co-authored-by trailers from agent git commit commands."""
import json
import re
import sys

CURSOR_TRAILER = re.compile(
    r"(?:\r?\n)?[ \t]*Co-authored-by:[ \t]*Cursor(?: Agent)?[ \t]*<cursoragent@cursor\.com>[ \t]*",
    re.IGNORECASE,
)
CURSOR_EMAIL = re.compile(
    r"(?:\r?\n)?[ \t]*Co-authored-by:[ \t]*.*<[^>\n]*@cursor\.com>[ \t]*",
    re.IGNORECASE,
)


def strip_trailers(text: str) -> str:
    out = CURSOR_TRAILER.sub("", text)
    out = CURSOR_EMAIL.sub("", out)
    return out


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print('{"permission":"allow"}')
        return

    payload = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else data
    command = payload.get("command") if isinstance(payload, dict) else None
    if not isinstance(command, str) or "commit" not in command:
        print('{"permission":"allow"}')
        return

    cleaned = strip_trailers(command)
    if cleaned == command:
        print('{"permission":"allow"}')
        return

    updated = dict(payload)
    updated["command"] = cleaned
    json.dump({"permission": "allow", "updated_input": updated}, sys.stdout)


if __name__ == "__main__":
    main()
