import Foundation

struct HostMeaning: Equatable {
    var mac: String
    var win: String

    static let unknown = HostMeaning(
        mac: "Sends this HID key. Meaning depends on the frontmost app.",
        win: "Sends this HID key. Meaning depends on the frontmost app."
    )
}

enum ShortcutCatalog {
    /// mods: 0x01 Ctrl, 0x02 Shift, 0x04 Alt/Opt, 0x08 GUI (⌘/Win)
    private static let table: [UInt16: HostMeaning] = {
        func k(_ mods: UInt8, _ code: UInt8) -> UInt16 {
            UInt16(mods) << 8 | UInt16(code)
        }
        let ctrl: UInt8 = 0x01, shift: UInt8 = 0x02, alt: UInt8 = 0x04, gui: UInt8 = 0x08
        return [
            // letters
            k(gui, 0x0E): .init(mac: "Cursor: inline AI edit (⌘K). Terminal: English→shell.",
                                win: "Win+K Cast/Connect. Cursor wants Ctrl+K, not this."),
            k(ctrl, 0x0E): .init(mac: "Ctrl+K. Cursor default is ⌘K, not this.",
                                 win: "Cursor: inline AI edit. ChatGPT: search chats."),
            k(gui, 0x0C): .init(mac: "Cursor: toggle Agent / AI sidepanel.",
                                win: "Win+I Settings. Cursor Agent is Ctrl+I."),
            k(ctrl, 0x0C): .init(mac: "Ctrl+I. Cursor default is ⌘I.",
                                 win: "Cursor: toggle Agent / AI sidepanel."),
            k(gui, 0x0F): .init(mac: "Cursor: toggle Chat. Selection → new chat.",
                                win: "Win+L Lock screen. Cursor Chat is Ctrl+L."),
            k(ctrl, 0x0F): .init(mac: "Ctrl+L. Cursor default is ⌘L.",
                                 win: "Cursor: toggle Chat. Selection → new chat."),
            k(gui | shift, 0x0F): .init(mac: "Cursor: add selection to current chat.",
                                        win: "Cursor: add selection to current chat (Ctrl+Shift+L). This is Shift+Win+L."),
            k(ctrl | shift, 0x0F): .init(mac: "Ctrl+Shift+L. Cursor default is ⌘⇧L.",
                                         win: "Cursor: add selection to current chat."),
            k(gui, 0x13): .init(mac: "Quick Open file (⌘P). VS Code / Cursor.",
                                win: "Win+P Project display. Cursor Quick Open is Ctrl+P."),
            k(ctrl, 0x13): .init(mac: "Ctrl+P print-ish in some apps. Cursor file open is ⌘P.",
                                 win: "Cursor / VS Code: Quick Open file."),
            k(gui | shift, 0x13): .init(mac: "Command Palette (⌘⇧P). Cursor / VS Code.",
                                        win: "This is Shift+Win+P. Palette is Ctrl+Shift+P."),
            k(ctrl | shift, 0x13): .init(mac: "Ctrl+Shift+P. Palette on Mac is ⌘⇧P.",
                                         win: "Command Palette. Cursor / VS Code."),
            k(gui, 0x37): .init(mac: "Cocoa Cancel. Cursor: Agent/Ask/Plan mode menu.",
                                win: "Win+. Emoji panel. Cursor mode menu is Ctrl+."),
            k(ctrl, 0x37): .init(mac: "Ctrl+.. Cursor mode menu on Mac is ⌘.",
                                 win: "Cursor: cycle Agent / Ask / Plan / Debug."),
            k(gui, 0x2C): .init(mac: "Spotlight (⌘Space).",
                                win: "Win+Space input language. Spotlight-equivalent is Win or search."),
            k(alt, 0x2C): .init(mac: "ChatGPT desktop: summon companion Chat Bar.",
                                win: "ChatGPT desktop: summon companion (Alt+Space). Same HID."),
            k(gui | shift, 0x2C): .init(mac: "Cursor: toggle Voice Mode (⌘⇧Space).",
                                        win: "Shift+Win+Space. Cursor Voice is Ctrl+Shift+Space."),
            k(ctrl | shift, 0x2C): .init(mac: "Ctrl+Shift+Space. Cursor Voice on Mac is ⌘⇧Space.",
                                         win: "Cursor: toggle Voice Mode."),
            k(gui, 0x08): .init(mac: "Cursor: toggle Agent layout (⌘E).",
                                win: "Win+E Explorer. Cursor Agent layout is Ctrl+E."),
            k(ctrl, 0x08): .init(mac: "Ctrl+E. Cursor Agent layout on Mac is ⌘E.",
                                 win: "Cursor: toggle Agent layout."),
            k(gui | shift, 0x0E): .init(mac: "Cursor: add selection to Inline Edit (⌘⇧K).",
                                        win: "Shift+Win+K. Add-to-edit is Ctrl+Shift+K."),
            k(ctrl | shift, 0x0E): .init(mac: "Ctrl+Shift+K delete line in VS Code. Cursor add-to-edit on Mac is ⌘⇧K.",
                                         win: "Cursor: add selection to Inline Edit. Also delete-line in VS Code."),
            k(gui | shift, 0x0D): .init(mac: "Cursor Settings (⌘⇧J).",
                                        win: "Shift+Win+J. Cursor Settings are Ctrl+Shift+J."),
            k(ctrl | shift, 0x0D): .init(mac: "Ctrl+Shift+J. Cursor Settings on Mac are ⌘⇧J.",
                                         win: "Cursor Settings."),
            k(gui | shift, 0x2A): .init(mac: "Cursor: cancel generation (⌘⇧⌫).",
                                        win: "Shift+Win+Backspace. Cancel is Ctrl+Shift+Backspace."),
            k(ctrl | shift, 0x2A): .init(mac: "Ctrl+Shift+Backspace. Cursor cancel on Mac is ⌘⇧⌫.",
                                         win: "Cursor: cancel generation."),
            k(alt, 0x28): .init(mac: "Cursor Inline Edit: ask a quick question (⌥↩).",
                                win: "Alt+Enter. Cursor quick question in inline edit."),
            k(gui, 0x11): .init(mac: "Cursor: new chat (⌘N). Also New window in many apps.",
                                win: "Win+N notification/new. Cursor new chat is Ctrl+N."),
            k(ctrl, 0x11): .init(mac: "Ctrl+N. Cursor new chat on Mac is ⌘N.",
                                 win: "Cursor: new chat."),
            k(gui, 0x17): .init(mac: "Cursor: new chat tab (⌘T). Browsers: new tab.",
                                win: "Win+T cycle taskbar. Cursor new chat tab is Ctrl+T."),
            k(ctrl, 0x17): .init(mac: "Ctrl+T. Cursor new chat tab on Mac is ⌘T.",
                                 win: "Cursor: new chat tab."),
            k(gui, 0x10): .init(mac: "Cursor: toggle file-reading strategies (⌘M).",
                                win: "Win+M minimize all. Cursor file-read toggle is Ctrl+M."),
            k(ctrl, 0x10): .init(mac: "Ctrl+M. Cursor file-read toggle on Mac is ⌘M.",
                                 win: "Cursor: toggle file-reading strategies."),
            k(gui | shift, 0x12): .init(mac: "ChatGPT: new chat (⌘⇧O).",
                                        win: "Shift+Win+O. ChatGPT new chat is Ctrl+Shift+O."),
            k(ctrl | shift, 0x12): .init(mac: "Ctrl+Shift+O. ChatGPT Mac uses ⌘⇧O.",
                                         win: "ChatGPT: new chat."),
            k(gui, 0x38): .init(mac: "ChatGPT: shortcut menu. Also comment-toggle in some editors is ⌘/.",
                                win: "Win+/ nothing standard. ChatGPT menu is Ctrl+/."),
            k(ctrl, 0x38): .init(mac: "Ctrl+/. ChatGPT Mac menu is ⌘/.",
                                 win: "ChatGPT: shortcut menu. Editors: toggle comment."),
            k(gui, 0x1A): .init(mac: "Close tab / window (⌘W).",
                                win: "Win+W nothing standard. Close tab is Ctrl+W."),
            k(ctrl, 0x1A): .init(mac: "Ctrl+W. Close tab on Mac is ⌘W.",
                                 win: "Close tab / document."),
            k(gui, 0x06): .init(mac: "Copy (⌘C).", win: "Win+C Copilot/charm in some builds. Copy is Ctrl+C."),
            k(ctrl, 0x06): .init(mac: "Ctrl+C. Copy on Mac is ⌘C. Terminal: interrupt.",
                                 win: "Copy."),
            k(gui, 0x19): .init(mac: "Paste (⌘V).", win: "Win+V clipboard history. Paste is Ctrl+V."),
            k(ctrl, 0x19): .init(mac: "Ctrl+V. Paste on Mac is ⌘V.", win: "Paste."),
            k(gui, 0x1B): .init(mac: "Cut (⌘X).", win: "Win+X Quick Link menu. Cut is Ctrl+X."),
            k(ctrl, 0x1B): .init(mac: "Ctrl+X. Cut on Mac is ⌘X.", win: "Cut."),
            k(gui, 0x1D): .init(mac: "Undo (⌘Z).", win: "Win+Z Snap layouts (Win11). Undo is Ctrl+Z."),
            k(ctrl, 0x1D): .init(mac: "Ctrl+Z. Undo on Mac is ⌘Z.", win: "Undo."),
            k(gui, 0x16): .init(mac: "Save (⌘S).", win: "Win+S Search. Save is Ctrl+S."),
            k(ctrl, 0x16): .init(mac: "Ctrl+S. Save on Mac is ⌘S.", win: "Save."),
            k(gui, 0x05): .init(mac: "Toggle sidebar (⌘B). Cursor / VS Code.",
                                win: "Win+B focus tray. Sidebar is Ctrl+B."),
            k(ctrl, 0x05): .init(mac: "Ctrl+B. Sidebar on Mac is ⌘B.",
                                 win: "Toggle sidebar. Cursor / VS Code."),
            k(gui, 0x0D): .init(mac: "Toggle panel / terminal (⌘J) in VS Code / Cursor.",
                                win: "Win+J nothing standard. Panel is Ctrl+J."),
            k(ctrl, 0x0D): .init(mac: "Ctrl+J. Panel on Mac is ⌘J.",
                                 win: "Toggle panel / terminal. Cursor / VS Code."),
            k(gui, 0x28): .init(mac: "Cursor: accept all AI diffs (⌘↩).",
                                win: "Win+Enter Narrator/desktop. Accept diffs is Ctrl+Enter."),
            k(ctrl, 0x28): .init(mac: "Ctrl+Enter. Cursor accept-all on Mac is ⌘↩.",
                                 win: "Cursor: accept all AI diffs. ChatGPT: send in some panes."),
            k(gui, 0x4F): .init(mac: "Cursor: accept next word of ghost text.",
                                win: "Win+Right snap window. Accept-word is Ctrl+Right."),
            k(ctrl, 0x4F): .init(mac: "Ctrl+Right jump word. Cursor accept-word is ⌘→.",
                                 win: "Cursor: accept next word of ghost text."),
            k(gui, 0x2F): .init(mac: "Outdent / navigate back (⌘[) in editors / browsers.",
                                win: "Win+[ nothing. Outdent/back is Ctrl+[."),
            k(gui, 0x30): .init(mac: "Indent / navigate forward (⌘]).",
                                win: "Win+] nothing. Indent/forward is Ctrl+]."),
            k(ctrl | shift, 0x16): .init(mac: "ChatGPT: toggle sidebar (⌘⇧S is the Mac binding).",
                                         win: "ChatGPT: toggle sidebar. Also Save As in many apps."),
            k(gui | shift, 0x16): .init(mac: "ChatGPT: toggle sidebar (⌘⇧S).",
                                        win: "Shift+Win+S Snip. ChatGPT sidebar is Ctrl+Shift+S."),
            k(gui | shift, 0x06): .init(mac: "ChatGPT: copy last response (⌘⇧C).",
                                        win: "Ctrl+Shift+C is the ChatGPT binding. This is Shift+Win+C."),
            k(ctrl | shift, 0x06): .init(mac: "Ctrl+Shift+C. ChatGPT Mac uses ⌘⇧C.",
                                         win: "ChatGPT: copy last response."),
            // bare keys
            k(0, 0x29): .init(mac: "Escape. Cursor: dismiss suggestion / close palette. ChatGPT: stop generating.",
                              win: "Same: cancel, dismiss, ChatGPT stop."),
            k(0, 0x28): .init(mac: "Return. Submit prompt / accept dialog / send ChatGPT.",
                              win: "Enter. Same: submit / send."),
            k(0, 0x2B): .init(mac: "Tab. Cursor: accept ghost autocomplete. Chat: next message.",
                              win: "Tab. Cursor: accept ghost autocomplete."),
            k(shift, 0x2B): .init(mac: "Cursor: rotate Agent modes (⇧Tab).",
                                  win: "Cursor: rotate Agent modes (Shift+Tab)."),
            k(0, 0x2C): .init(mac: "Space.", win: "Space."),
            k(0, 0x4C): .init(mac: "Forward Delete (not ⌫). Deletes to the right.",
                              win: "Delete. Deletes to the right."),
            k(0, 0x2A): .init(mac: "Backspace / Delete-left.", win: "Backspace."),
            k(0, 0x4F): .init(mac: "Right arrow. Cursor: move / accept word if modified.",
                              win: "Right arrow."),
            k(0, 0x50): .init(mac: "Left arrow.", win: "Left arrow."),
            k(0, 0x51): .init(mac: "Down arrow. Next item in palettes / chat history.",
                              win: "Down arrow. Same."),
            k(0, 0x52): .init(mac: "Up arrow. Previous item / last chat prompt.",
                              win: "Up arrow. Same."),
        ]
    }()

    static func meaning(for binding: PadBinding) -> HostMeaning {
        switch binding.kind {
        case .empty:
            return HostMeaning(mac: "Unbound. Sends nothing.", win: "Unbound. Sends nothing.")
        case .media:
            return HostMeaning(mac: "Media key: \(binding.macLabel).", win: "Media key: \(binding.winLabel).")
        case .mouse:
            return HostMeaning(mac: binding.mouse.label, win: binding.mouse.label)
        case .key:
            guard let step = binding.steps.first else { return .unknown }
            let id = UInt16(step.mods) << 8 | UInt16(step.code)
            return table[id] ?? .unknown
        }
    }

    static func guide(for binding: PadBinding) -> ChordGuide {
        switch binding.kind {
        case .empty:
            return ChordGuide(app: "", title: "Empty", how: "Nothing is bound. Switch to Write and capture a shortcut.")
        case .media, .mouse:
            return ChordGuide(app: "", title: binding.label, how: meaning(for: binding).mac)
        case .key:
            guard let step = binding.steps.first else {
                return ChordGuide(app: "", title: binding.label, how: HostMeaning.unknown.mac)
            }
            let id = UInt16(step.mods) << 8 | UInt16(step.code)
            if let g = guides[id] { return g }
            let sense = meaning(for: binding)
            return ChordGuide(app: "", title: binding.macLabel, how: sense.mac)
        }
    }

    /// Fingerprint a layer against known kits. ≥3 matching slots = that kit.
    static func detect(_ layer: LayerProfile) -> DetectedKit {
        let candidates: [(DetectedKit, LayerProfile)] = [
            (.cursorMac, cursorMacLayer),
            (.cursorWin, cursorWinLayer),
            (.chatGPTMac, chatGPTMacLayer),
            (.chatGPTWin, chatGPTWinLayer),
        ]
        let scored = candidates.map { kit, preset -> (DetectedKit, Int) in
            let n = ControlID.allCases.reduce(0) { acc, id in
                let a = layer[id], b = preset[id]
                return acc + ((!a.isEmpty && a == b) ? 1 : 0)
            }
            return (kit, n)
        }
        let best = scored.max(by: { $0.1 < $1.1 }) ?? (.unknown, 0)
        if best.1 >= 3 { return best.0 }
        if cursorish(layer) { return .cursorMac }
        return .unknown
    }

    private static func cursorish(_ layer: LayerProfile) -> Bool {
        let chords = ControlID.allCases.compactMap { id -> UInt16? in
            let b = layer[id]
            guard b.kind == .key, let s = b.steps.first else { return nil }
            return UInt16(s.mods) << 8 | UInt16(s.code)
        }
        let cursorIDs: Set<UInt16> = [
            0x08_0E, 0x08_0C, 0x08_0F, 0x08_08, 0x08_37,
            0x0A_0F, 0x0A_0E, 0x08_28, 0x08_4F, 0x00_2B,
        ]
        return chords.filter { cursorIDs.contains($0) }.count >= 2
    }

    fileprivate static let guides: [UInt16: ChordGuide] = {
        func k(_ mods: UInt8, _ code: UInt8) -> UInt16 {
            UInt16(mods) << 8 | UInt16(code)
        }
        let ctrl: UInt8 = 0x01, shift: UInt8 = 0x02, alt: UInt8 = 0x04, gui: UInt8 = 0x08
        let cursor = "Cursor"
        return [
            k(gui, 0x0E): .init(
                app: cursor, title: "Inline Edit",
                how: "Select code (or park the caret) in Cursor, press this key, type what to change, Return to submit. Esc cancels. In the terminal it opens the English→shell prompt."
            ),
            k(ctrl, 0x0E): .init(
                app: cursor, title: "Inline Edit (Win)",
                how: "Windows Cursor inline edit (Ctrl+K). On Mac this is Ctrl+K, not ⌘K — only use it if you remapped Cursor."
            ),
            k(gui, 0x0C): .init(
                app: cursor, title: "Agent panel",
                how: "Toggles the Agent / AI sidepanel. Press again to hide. If you bound this key to a mode in Cursor settings, it jumps straight to that mode instead."
            ),
            k(ctrl, 0x0C): .init(
                app: cursor, title: "Agent panel (Win)",
                how: "Windows Cursor Agent (Ctrl+I). On Mac the default is ⌘I."
            ),
            k(gui, 0x0F): .init(
                app: cursor, title: "Chat",
                how: "Toggles Chat. With code selected, this starts a new chat that already has the selection as context."
            ),
            k(ctrl, 0x0F): .init(
                app: cursor, title: "Chat (Win)",
                how: "Windows Cursor Chat (Ctrl+L). On Mac the default is ⌘L. Do not use Win+L — that locks Windows."
            ),
            k(gui | shift, 0x0F): .init(
                app: cursor, title: "Add to Chat",
                how: "Select code first, then press. The selection is attached to the current chat as context (does not open a new thread)."
            ),
            k(ctrl | shift, 0x0F): .init(
                app: cursor, title: "Add to Chat (Win)",
                how: "Windows: Ctrl+Shift+L adds the selection to the current chat."
            ),
            k(gui | shift, 0x0E): .init(
                app: cursor, title: "Add to Edit",
                how: "Select code, press this key — it drops the selection into Inline Edit. Same family as ⌘K, but keeps the prompt focused."
            ),
            k(gui, 0x08): .init(
                app: cursor, title: "Agent layout",
                how: "Toggles the Agent editor layout (⌘E). Use when you want the agent pane to take over the workbench."
            ),
            k(gui, 0x37): .init(
                app: cursor, title: "Mode menu",
                how: "Opens Agent / Ask / Plan / Debug. Tap, then pick a mode. Does not send a prompt by itself."
            ),
            k(ctrl, 0x37): .init(
                app: cursor, title: "Mode menu (Win)",
                how: "Windows Cursor mode menu is Ctrl+. On Mac it is ⌘."
            ),
            k(gui, 0x38): .init(
                app: cursor, title: "Cycle models",
                how: "In Cursor this loops AI models. In ChatGPT desktop it opens the shortcut menu. In many editors it toggles comments."
            ),
            k(gui | shift, 0x13): .init(
                app: cursor, title: "Command Palette",
                how: "Opens the palette. Type a command name (Keyboard Shortcuts, Cursor Settings, etc.) and Return."
            ),
            k(ctrl | shift, 0x13): .init(
                app: cursor, title: "Command Palette (Win)",
                how: "Windows / Linux palette (Ctrl+Shift+P). On Mac it is ⌘⇧P."
            ),
            k(gui, 0x13): .init(
                app: cursor, title: "Quick Open",
                how: "Fuzzy-find a file in the workspace. Type, then Return to open."
            ),
            k(gui | shift, 0x2C): .init(
                app: cursor, title: "Voice Mode",
                how: "Toggles Cursor Voice Mode. Talk instead of typing into Agent/Chat. Press again to stop."
            ),
            k(gui | shift, 0x0D): .init(
                app: cursor, title: "Cursor Settings",
                how: "Opens Cursor Settings (⌘⇧J). Not the VS Code settings UI (that's ⌘,)."
            ),
            k(gui, 0x28): .init(
                app: cursor, title: "Accept / Send",
                how: "In a diff: accept all suggested changes. In Chat while typing: force-send. Also searches the codebase when the chat box is empty."
            ),
            k(gui, 0x2A): .init(
                app: cursor, title: "Reject all",
                how: "Rejects all pending AI diffs in the current Agent/edit session."
            ),
            k(gui | shift, 0x2A): .init(
                app: cursor, title: "Cancel generation",
                how: "Stops the in-flight model run (⌘⇧⌫). Safe to mash if Agent is stuck streaming."
            ),
            k(alt, 0x28): .init(
                app: cursor, title: "Quick question",
                how: "Inside Inline Edit, asks a quick question about the selection without applying a rewrite."
            ),
            k(gui, 0x4F): .init(
                app: cursor, title: "Accept word",
                how: "Accepts the next word of ghost Tab-autocomplete. Keep tapping to take more of the suggestion."
            ),
            k(0, 0x2B): .init(
                app: cursor, title: "Accept Tab",
                how: "In the editor: accept the full ghost suggestion. In Chat: cycle to the next message. Shift+Tab (not this key) rotates Agent modes."
            ),
            k(shift, 0x2B): .init(
                app: cursor, title: "Rotate Agent modes",
                how: "While Agent is focused, ⇧Tab cycles Agent / Ask / Plan / Debug. Does not accept autocomplete — that is plain Tab."
            ),
            k(0, 0x29): .init(
                app: cursor, title: "Escape",
                how: "Dismiss autocomplete, close the palette, unfocus Chat input, or abort a half-typed inline prompt."
            ),
            k(0, 0x28): .init(
                app: cursor, title: "Submit",
                how: "Submit Inline Edit, send / nudge Chat, accept a dialog."
            ),
            k(0, 0x52): .init(
                app: cursor, title: "Up",
                how: "Previous item in palettes, or last prompt in Chat."
            ),
            k(0, 0x51): .init(
                app: cursor, title: "Down",
                how: "Next item in palettes / Chat history."
            ),
            k(gui, 0x11): .init(
                app: cursor, title: "New chat",
                how: "Starts a new Chat/Agent thread (⌘N)."
            ),
            k(gui, 0x17): .init(
                app: cursor, title: "New chat tab",
                how: "Opens another chat tab (⌘T) so you can run parallel threads."
            ),
            k(gui, 0x10): .init(
                app: cursor, title: "File reading",
                how: "Toggles how Agent reads files (⌘M)."
            ),
            k(gui, 0x2F): .init(
                app: cursor, title: "Previous chat",
                how: "In Chat: previous thread (⌘[). In the editor it is usually outdent / back."
            ),
            k(gui, 0x30): .init(
                app: cursor, title: "Next chat",
                how: "In Chat: next thread (⌘]). In the editor it is usually indent / forward."
            ),
            k(alt, 0x2C): .init(
                app: "ChatGPT", title: "Summon ChatGPT",
                how: "Brings up the ChatGPT desktop companion (⌥Space / Alt+Space — same HID on Mac and Windows)."
            ),
            k(gui | shift, 0x12): .init(
                app: "ChatGPT", title: "New ChatGPT chat",
                how: "ChatGPT desktop: new chat (⌘⇧O)."
            ),
        ]
    }()
}

struct ChordGuide: Equatable {
    var app: String
    var title: String
    var how: String
}

enum DetectedKit: Equatable {
    case cursorMac, cursorWin, chatGPTMac, chatGPTWin, unknown

    var title: String {
        switch self {
        case .cursorMac: return "Cursor Mac"
        case .cursorWin: return "Cursor Win"
        case .chatGPTMac: return "ChatGPT Mac"
        case .chatGPTWin: return "ChatGPT Win"
        case .unknown: return "Custom"
        }
    }

    var hint: String {
        switch self {
        case .cursorMac:
            return "This layer looks like a Cursor Mac kit. Focus Cursor, then press a pad key."
        case .cursorWin:
            return "This layer looks like Cursor on Windows (Ctrl chords). On this Mac those become Ctrl, not ⌘."
        case .chatGPTMac:
            return "This layer looks like ChatGPT desktop on Mac. Focus the ChatGPT app."
        case .chatGPTWin:
            return "This layer looks like ChatGPT on Windows. Alt+Space is the same HID as ⌥Space."
        case .unknown:
            return "No stock kit matched. Guides below are from each chord."
        }
    }
}

struct PadPreset: Identifiable {
    let id: String
    let title: String
    let blurb: String
    /// If set, written across L1… instead of only the current layer.
    let layers: [LayerProfile]

    static let all: [PadPreset] = [cursorMac, cursorWin, chatGPTMac, chatGPTWin, vibeKit]

    static let cursorMac = PadPreset(
        id: "cursor-mac",
        title: "Cursor Mac",
        blurb: "⌘K inline · ⌘I agent · ⌘L chat · knob Esc / ↩ / Tab",
        layers: [cursorMacLayer]
    )

    static let cursorWin = PadPreset(
        id: "cursor-win",
        title: "Cursor Win",
        blurb: "Ctrl+K / I / L — do not use ⌘, Win+K is Cast",
        layers: [cursorWinLayer]
    )

    static let chatGPTMac = PadPreset(
        id: "gpt-mac",
        title: "ChatGPT Mac",
        blurb: "⌥Space summon · ⌘⇧O new · ⌘K search",
        layers: [chatGPTMacLayer]
    )

    static let chatGPTWin = PadPreset(
        id: "gpt-win",
        title: "ChatGPT Win",
        blurb: "Alt+Space · Ctrl+⇧O new · Ctrl+K search",
        layers: [chatGPTWinLayer]
    )

    static let vibeKit = PadPreset(
        id: "vibe-kit",
        title: "Vibe kit (all layers)",
        blurb: "L1 Cursor Mac · L2 ChatGPT Mac · L3 Cursor Win",
        layers: [cursorMacLayer, chatGPTMacLayer, cursorWinLayer]
    )
}

private let gui: UInt8 = 0x08
private let ctrl: UInt8 = 0x01
private let shift: UInt8 = 0x02
private let alt: UInt8 = 0x04

private func layer(_ map: [ControlID: PadBinding]) -> LayerProfile {
    var profile = LayerProfile.blank
    for (id, binding) in map { profile[id] = binding }
    return profile
}

private let cursorMacLayer = layer([
    .key1: .key(gui, 0x0E),      // ⌘K inline
    .key2: .key(gui, 0x0C),      // ⌘I agent
    .key3: .key(gui, 0x0F),      // ⌘L chat
    .knobCCW: .key(0, 0x29),     // Esc
    .knobPress: .key(0, 0x28),   // Enter
    .knobCW: .key(0, 0x2B),      // Tab accept
])

private let cursorWinLayer = layer([
    .key1: .key(ctrl, 0x0E),
    .key2: .key(ctrl, 0x0C),
    .key3: .key(ctrl, 0x0F),
    .knobCCW: .key(0, 0x29),
    .knobPress: .key(0, 0x28),
    .knobCW: .key(0, 0x2B),
])

private let chatGPTMacLayer = layer([
    .key1: .key(alt, 0x2C),           // ⌥Space
    .key2: .key(gui | shift, 0x12),   // ⌘⇧O
    .key3: .key(gui, 0x0E),           // ⌘K search
    .knobCCW: .key(0, 0x52),          // Up
    .knobPress: .key(0, 0x28),        // Enter send
    .knobCW: .key(0, 0x51),           // Down
])

private let chatGPTWinLayer = layer([
    .key1: .key(alt, 0x2C),            // Alt+Space (same HID)
    .key2: .key(ctrl | shift, 0x12),   // Ctrl+Shift+O
    .key3: .key(ctrl, 0x0E),           // Ctrl+K
    .knobCCW: .key(0, 0x52),
    .knobPress: .key(0, 0x28),
    .knobCW: .key(0, 0x51),
])
