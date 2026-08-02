import Cocoa
import SwiftUI

/// Observable UI state shared between SwiftUI views and the window manager.
@Observable
final class UIState {
    var isWindowVisible: Bool = false
    var detachedPanels: Set<PanelType> = []
    var settingsVisible: Bool = false
    var onDetachPanel: ((PanelType) -> Void)?
    var onReattachPanel: ((PanelType) -> Void)?
    var onEdgeTriggerChange: ((Bool) -> Void)?
    var onDragToEdgeChange: ((Bool) -> Void)?
    var onHotkeyChange: ((UInt32, UInt32) -> Void)?
    var onHistoryLimitChange: ((Int) -> Void)?
}

/// Manages the dropdown panel window: creation, show/hide animation,
/// edge-trigger coordination, and detached panel windows.
final class WindowManager {
    private var panel: DropDownPanel?
    
    private(set) var uiState = UIState()
    let edgeTracker = TopEdgeTracker()
    private let hotkeyManager = GlobalHotkeyManager()

    private let clipboard: ClipboardMonitor
    private let notes: NotesManager
    private let files: FileStagingManager
    private let todos: TodoManager
    private let settings: AppSettings
    private let persistence: PersistenceManager

    private var detachedWindows: [PanelType: DetachedPanel] = [:]
    private var isAnimating = false
    private var animationTimer: Timer?

    init(persistence: PersistenceManager, clipboard: ClipboardMonitor, notes: NotesManager, files: FileStagingManager, todos: TodoManager, settings: AppSettings) {
        self.persistence = persistence
        self.clipboard = clipboard
        self.notes = notes
        self.files = files
        self.todos = todos
        self.settings = settings
        setupWindow()
        setupEdgeTracker()
        setupHotkey()
    }

    // MARK: - Setup

    private func setupWindow() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let width = settings.panelOrder.reduce(into: CGFloat(0)) { acc, p in
            acc += settings.panelWidths[p] ?? 250
        }
        let height = settings.windowHeight
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY

        let panel = DropDownPanel(contentRect: NSRect(x: x, y: y, width: width, height: height))
        panel.alphaValue = 0

        let content = MainContentView()
            .environment(clipboard)
            .environment(notes)
            .environment(files)
            .environment(todos)
            .environment(settings)
            .environment(uiState)

        let controller = NSHostingController(rootView: content)
        panel.contentViewController = controller
        panel.setContentSize(NSSize(width: width, height: height))

        self.panel = panel
    }

    private func setupEdgeTracker() {
        edgeTracker.isEnabled = settings.edgeTriggerEnabled
        edgeTracker.dragToTopEnabled = settings.dragToEdgeEnabled
        edgeTracker.onShow = { [weak self] in self?.show(source: .edge) }
        edgeTracker.onHide = { [weak self] in self?.hide() }
        edgeTracker.onDragToTop = { [weak self] in self?.show(source: .drag) }
        edgeTracker.start()
    }

    private func setupHotkey() {
        hotkeyManager.onHotkey = { [weak self] in self?.toggle() }
        hotkeyManager.register(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)
    }

    func updateHotkey(keyCode: UInt32, modifiers: UInt32) {
        settings.hotkeyCode = keyCode
        settings.hotkeyModifiers = modifiers
        hotkeyManager.unregister()
        hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
    }

    func updateEdgeTrigger(enabled: Bool) {
        settings.edgeTriggerEnabled = enabled
        edgeTracker.isEnabled = enabled
    }

    func updateDragToEdge(enabled: Bool) {
        settings.dragToEdgeEnabled = enabled
        edgeTracker.dragToTopEnabled = enabled
    }

    // MARK: - Show / Hide

    func toggle() {
        if uiState.isWindowVisible { hide() } else { show(source: .hotkey) }
    }

    func show(source: TopEdgeTracker.ShowSource = .hotkey) {
        guard !uiState.isWindowVisible, !isAnimating else { return }
        guard let panel = panel, let screen = screenWithMouse() else { return }

        isAnimating = true
        uiState.isWindowVisible = true
        edgeTracker.windowDidShow(source: source)

        let screenWidth = screen.frame.width
        let height = settings.windowHeight
        let targetY = screen.frame.maxY - height
        let startY = screen.frame.maxY
        let x = screen.frame.minX
        let alpha = CGFloat(settings.windowOpacity)

        // Start: above screen, full alpha immediately (no fade — clean slide)
        panel.setFrame(NSRect(x: x, y: startY, width: screenWidth, height: height), display: false)
        panel.alphaValue = alpha
        panel.orderFrontRegardless()

        // Slide-down: 20 steps, 0.15s, easeOutQuart
        let steps = 30
        let dt = 0.30 / Double(steps)
        var step = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] timer in
            guard let self = self, let panel = self.panel else { timer.invalidate(); return }
            step += 1
            let p = CGFloat(step) / CGFloat(steps)
            let eased = 1.0 - pow(1.0 - p, 4)
            let y = startY + (targetY - startY) * eased
            panel.setFrame(NSRect(x: x, y: y, width: screenWidth, height: height), display: true)
            if step >= steps {
                timer.invalidate()
                self.animationTimer = nil
                self.isAnimating = false
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    func hide() {
        guard uiState.isWindowVisible, !isAnimating else { return }
        guard let panel = panel, let screen = screenWithMouse() else { return }

        isAnimating = true
        uiState.isWindowVisible = false
        edgeTracker.windowDidHide()

        let sf = panel.frame
        let endY = screen.frame.maxY

        // Slide-up: 16 steps, 0.12s, easeInQuart
        let steps = 24
        let dt = 0.25 / Double(steps)
        var step = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] timer in
            guard let self = self, let panel = self.panel else { timer.invalidate(); return }
            step += 1
            let p = CGFloat(step) / CGFloat(steps)
            let eased = pow(p, 4)
            let y = sf.minY + (endY - sf.minY) * eased
            panel.setFrame(NSRect(x: sf.minX, y: y, width: sf.width, height: sf.height), display: true)
            if step >= steps {
                timer.invalidate()
                self.animationTimer = nil
                panel.orderOut(nil)
                self.isAnimating = false
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    // MARK: - Screen helpers

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
    }

    // MARK: - Detached panels

    func detachPanel(_ type: PanelType) {
        guard detachedWindows[type] == nil else { return }
        uiState.detachedPanels.insert(type)

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let width: CGFloat = settings.panelWidths[type] ?? 260
        let height: CGFloat = settings.windowHeight
        let x = screen.frame.minX + 40 + CGFloat(detachedWindows.count * 30)
        let y = screen.frame.maxY - height - 40

        let detachedPanel = DetachedPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            title: type.title
        )

       let content = panelContentView(for: type)
            .environment(clipboard)
            .environment(notes)
            .environment(files)
            .environment(todos)
            .environment(settings)
            .environment(uiState)

       let controller = NSHostingController(rootView: AnyView(content))
        detachedPanel.contentViewController = controller
        detachedPanel.makeKeyAndOrderFront(nil)

        detachedWindows[type] = detachedPanel
    }

    func reattachPanel(_ type: PanelType) {
        if let window = detachedWindows[type] {
            window.orderOut(nil)
            detachedWindows[type] = nil
        }
        uiState.detachedPanels.remove(type)
    }

    @ViewBuilder
    private func panelContentView(for type: PanelType) -> some View {
        switch type {
        case .clipboard:
            ClipboardPanelView()
        case .files:
            FilesPanelView()
        case .notes:
            NotesPanelView()
        case .todo:
            TodoPanelView()
        }
    }

    // MARK: - Cleanup

    func teardown() {
        edgeTracker.stop()
        hotkeyManager.unregister()
        clipboard.stop()
        for window in detachedWindows.values {
            window.orderOut(nil)
        }
        detachedWindows.removeAll()
        panel?.orderOut(nil)
    }
}
