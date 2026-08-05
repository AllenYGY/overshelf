import Cocoa
import SwiftUI

/// Main app delegate: creates services, window manager, and status bar.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let persistence: PersistenceManager
    let clipboard: ClipboardMonitor
    let notes: NotesManager
    let files: FileStagingManager
    let settings: AppSettings
    let todos: TodoManager
    let windowManager: WindowManager
    private let readmeDemoScene: ReadmeDemoScene?
    private let settingsWindowController = SettingsWindowController()
    private var settingsMonitor: Any?

    override init() {
        let readmeDemoScene = ReadmeDemoScene.parse(arguments: CommandLine.arguments)
        self.readmeDemoScene = readmeDemoScene

        if readmeDemoScene != nil || Self.readmeDemoProgress != nil {
            let demoURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("OverShelf-ReadmeDemo", isDirectory: true)
            self.persistence = PersistenceManager(baseURL: demoURL)
        } else {
            self.persistence = PersistenceManager()
        }
        if let readmeDemoScene {
            ReadmeDemoData.seed(scene: readmeDemoScene, into: persistence)
        }
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
        uiState.onLiveHeightChange = { [weak self] h in self?.windowManager.resizeHeight(to: h) }
        uiState.onAppearanceChange = { [weak self] mode in self?.applyAppearance(mode) }
        uiState.onOpacityChange = { [weak self] opacity in self?.windowManager.updateOpacity(opacity) }
        applyAppearance(settings.appearanceMode)
        showReadmeDemoFrameIfRequested()

        // Start clipboard monitoring
        if readmeDemoScene == nil && Self.readmeDemoProgress == nil {
            clipboard.start()
        }

        // Cmd+, opens preferences whenever the app owns the key window
        // (dropdown panel, detached panel, or the settings window itself).
        settingsMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            if mods == [.command], event.charactersIgnoringModifiers == "," {
                self?.showSettings()
                return nil
            }
            return event
        }


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
        notes.flush()
        todos.flush()
        if let m = settingsMonitor { NSEvent.removeMonitor(m) }
        windowManager.teardown()
    }

    // Show window when app is activated (e.g. from Dock - but we're LSUIElement)
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        windowManager.hide()
        let content = NSHostingController(
            rootView: SettingsView()
                .environment(clipboard)
                .environment(notes)
                .environment(files)
                .environment(settings)
                .environment(windowManager.uiState)
        )
        settingsWindowController.show(content: content)
    }

    private func applyAppearance(_ mode: AppearanceMode) {
        settings.appearanceMode = mode
        NSApp.appearance = mode.appKitName.flatMap(NSAppearance.init(named:))
    }

    private static var readmeDemoProgress: CGFloat? {
        let prefix = "--readme-demo-frame="
        guard let argument = CommandLine.arguments.first(where: { $0.hasPrefix(prefix) }),
              let value = Double(argument.dropFirst(prefix.count)) else {
            return nil
        }
        return CGFloat(value)
    }

    private func showReadmeDemoFrameIfRequested() {
        guard let progress = Self.readmeDemoProgress else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.windowManager.showDemoFrame(progress: progress)
        }
    }

}
