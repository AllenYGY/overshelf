import SwiftUI

@main
struct DropShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Status bar icon + menu using native MenuBarExtra
        MenuBarExtra("DropShelf", systemImage: "rectangle.stack.badge.plus") {
            Button("Show/Hide DropShelf") { appDelegate.windowManager.toggle() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            Divider()
            SettingsLink { Text("Preferences…") }
            Divider()
            Button("Quit DropShelf") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
                .environment(appDelegate.clipboard)
                .environment(appDelegate.notes)
                .environment(appDelegate.files)
                .environment(appDelegate.settings)
                .environment(appDelegate.windowManager.uiState)
        }
        .commands {
            CommandMenu("DropShelf") {
                Button("Toggle Window") { appDelegate.windowManager.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Button("Clear Clipboard History") { appDelegate.clipboard.clearHistory() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}
