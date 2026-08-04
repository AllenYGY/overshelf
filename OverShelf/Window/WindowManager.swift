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
    var onLiveHeightChange: ((CGFloat) -> Void)?
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
        let height = settings.windowHeight
        let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY, width: screen.frame.width, height: height)

        let panel = DropDownPanel(contentRect: frame)
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

        self.panel = panel
    }

    private func setupEdgeTracker() {
        edgeTracker.isEnabled = settings.edgeTriggerEnabled
        edgeTracker.dragToTopEnabled = settings.dragToEdgeEnabled
        edgeTracker.panelFrameProvider = { [weak self] in self?.panel?.frame ?? .zero }
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
        guard !uiState.isWindowVisible else { return }
        guard let panel = panel, let screen = screenWithMouse() else { return }

        animationTimer?.invalidate()
        animationTimer = nil
        uiState.isWindowVisible = true
        edgeTracker.windowDidShow(source: source)

        let height = settings.windowHeight
        let targetFrame = dropdownPanelFrame(screenFrame: screen.frame, height: height)
        let alpha = CGFloat(settings.windowOpacity)

        // Start fully above the screen; slide down with a gentle ease-in-out.
        panel.setFrame(targetFrame.offsetBy(dx: 0, dy: height), display: false)
        panel.alphaValue = alpha
        panel.orderFrontRegardless()

        animate(duration: 1.4, from: targetFrame.offsetBy(dx: 0, dy: height), to: targetFrame) { }
    }

    func hide() {
        guard uiState.isWindowVisible else { return }
        guard let panel = panel, let screen = screenWithMouse() else { return }

        animationTimer?.invalidate()
        animationTimer = nil
        uiState.isWindowVisible = false
        edgeTracker.windowDidHide()

        let startFrame = panel.frame
        let endFrame = startFrame.offsetBy(dx: 0, dy: screen.frame.maxY - startFrame.minY)
        animate(duration: 1.1, from: startFrame, to: endFrame) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }

    /// Time-based slide animation (60 Hz) with an ease-in-out curve, so motion
    /// starts and ends gently regardless of timer jitter.
    private func animate(duration: TimeInterval, from startFrame: NSRect, to endFrame: NSRect, completion: @escaping () -> Void) {
        isAnimating = true
        let start = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self, let panel = self.panel else { timer.invalidate(); return }
            let p = CGFloat(min(1, Date().timeIntervalSince(start) / duration))
            let eased = Self.easeInOutCubic(p)
            let frame = NSRect(
                x: startFrame.minX + (endFrame.minX - startFrame.minX) * eased,
                y: startFrame.minY + (endFrame.minY - startFrame.minY) * eased,
                width: startFrame.width,
                height: startFrame.height
            )
            panel.setFrame(frame, display: true)
            if p >= 1 {
                timer.invalidate()
                self.animationTimer = nil
                self.isAnimating = false
                completion()
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    static func easeInOutCubic(_ p: CGFloat) -> CGFloat {
        p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
    }

    /// Live-resize the panel height while anchored to the top of the screen.
    /// Called by the bottom drag handle; persisted by the view on gesture end.
    func resizeHeight(to height: CGFloat) {
        guard uiState.isWindowVisible, !isAnimating, let panel = panel else { return }
        let screen = panel.screen ?? screenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first!
        panel.setFrame(dropdownPanelFrame(screenFrame: screen.frame, height: height), display: true)
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
        detachedPanel.onClose = { [weak self] in
            self?.reattachPanel(type)
        }

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
