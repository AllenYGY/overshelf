import Cocoa
import SwiftUI

/// Main app delegate: creates services, window manager, and status bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let persistence = PersistenceManager()
    let clipboard: ClipboardMonitor
    let notes: NotesManager
    let files: FileStagingManager
    let settings: AppSettings
    let todos: TodoManager
    let windowManager: WindowManager

   override init() {
        self.clipboard = ClipboardMonitor(persistence: persistence)
        self.notes = NotesManager(persistence: persistence)
        self.files = FileStagingManager(persistence: persistence)
        self.settings = AppSettings(persistence: persistence)
        self.todos = TodoManager(persistence: persistence)
        self.windowManager = WindowManager(
            persistence: persistence,
            clipboard: clipboard,
            notes: notes,
            files: files,
            todos: todos,
            settings: settings
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wire up UIState callbacks
        let uiState = windowManager.uiState
        uiState.onDetachPanel = { [weak self] panel in self?.windowManager.detachPanel(panel) }
        uiState.onReattachPanel = { [weak self] panel in self?.windowManager.reattachPanel(panel) }
        uiState.onEdgeTriggerChange = { [weak self] enabled in self?.windowManager.updateEdgeTrigger(enabled: enabled) }
        uiState.onDragToEdgeChange = { [weak self] enabled in self?.windowManager.updateDragToEdge(enabled: enabled) }
        uiState.onHotkeyChange = { [weak self] code, mods in self?.windowManager.updateHotkey(keyCode: code, modifiers: mods) }
        uiState.onHistoryLimitChange = { [weak self] limit in self?.clipboard.setLimit(limit) }

        // Start clipboard monitoring
        clipboard.start()


        // Listen for detach notifications from SwiftUI views
        NotificationCenter.default.addObserver(
            forName: .windowDetach,
            object: nil,
            queue: .main
        ) { [weak self] note in
            if let panel = note.userInfo?["panel"] as? PanelType {
                self?.windowManager.detachPanel(panel)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.teardown()
    }

    // Show window when app is activated (e.g. from Dock - but we're LSUIElement)
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }
}
