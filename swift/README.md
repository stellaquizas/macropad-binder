# macOS

Native SwiftUI app. Same pad and protocol as the Windows UI.

## Run

macOS 14+ and Xcode command-line tools.

```bash
cd swift
./run.sh
```

Or:

```bash
cd swift
swift build -c release
.build/release/MacropadBinder
```

The app is not sandboxed (needs HID). Does not send bootloader (`0xEF`) or variant (`0xFC`) commands.

Default mode is **Read**. Switch to **Write** to capture (`⌘K`) and flash (`⌘S`).
