import AppKit
import SwiftUI

@main
struct MacropadBinderApp: App {
    @StateObject private var store = PadStore()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Macropad Binder") {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    store.start()
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 960, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Pad") {
                Button("Read from pad") { Task { await store.readFromDevice() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!store.programmable)
                Button("Write to pad") { store.requestWrite() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!store.programmable || store.mode != .write || !store.dirty)
                Button("Revert unsaved") { store.revert() }
                    .disabled(!store.programmable || store.mode != .write || !store.dirty)
                Divider()
                Button("Capture shortcut") { store.beginCapture() }
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(!store.programmable || store.mode != .write)
            }
        }
    }
}
