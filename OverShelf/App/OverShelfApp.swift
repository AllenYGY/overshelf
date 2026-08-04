import SwiftUI

@main
struct OverShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Status bar icon + menu using native MenuBarExtra
        MenuBarExtra("OverShelf", systemImage: "rectangle.stack.badge.plus") {
            StatusBarMenu(appDelegate: appDelegate)
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
            CommandMenu("OverShelf") {
                Button("Toggle Window") { appDelegate.windowManager.toggle() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Divider()
                Button("Clear Clipboard History") { appDelegate.clipboard.clearHistory() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}

private struct StatusBarMenu: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Show/Hide OverShelf") { appDelegate.windowManager.toggle() }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        Divider()

        Button("New Note") {
            appDelegate.windowManager.show(source: .hotkey)
            appDelegate.notes.createNote()
        }

        Button("New Todo") {
            appDelegate.windowManager.show(source: .hotkey)
            appDelegate.todos.createTodo(title: "New task")
        }

        Button("Clear Clipboard History") {
            appDelegate.clipboard.clearHistory()
        }

        Menu("Panels") {
            ForEach(PanelType.allCases) { panel in
                let visible = !appDelegate.settings.hiddenPanels.contains(panel)
                Button {
                    var hidden = appDelegate.settings.hiddenPanels
                    if visible {
                        if appDelegate.settings.panelOrder.count - hidden.count > 1 {
                            hidden.insert(panel)
                        }
                    } else {
                        hidden.remove(panel)
                    }
                    appDelegate.settings.hiddenPanels = hidden
                } label: {
                    Label(panel.title, systemImage: visible ? "checkmark" : "minus")
                }
            }
        }

        Divider()

        Button("Preferences…") {
            appDelegate.windowManager.hide()
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        Button("Quit OverShelf") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
