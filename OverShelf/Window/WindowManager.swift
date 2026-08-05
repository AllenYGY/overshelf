import Cocoa
import SwiftUI

/// Observable UI state shared between SwiftUI views and the window manager.
@Observable
final class UIState {
    var isWindowVisible: Bool = false
    /// The isolated README demo scene, when launched with a demo argument.
    var readmeDemoScene: ReadmeDemoScene?
    var detachedPanels: Set<PanelType> = []
    var settingsVisible: Bool = false
    var onDetachPanel: ((PanelType) -> Void)?
    var onReattachPanel: ((PanelType) -> Void)?
    var onEdgeTriggerChange: ((Bool) -> Void)?
    var onDragToEdgeChange: ((Bool) -> Void)?
    var onHotkeyChange: ((UInt32, UInt32) -> Void)?
    var onHistoryLimitChange: ((Int) -> Void)?
    var onLiveHeightChange: ((CGFloat) -> Void)?
    var onAppearanceChange: ((AppearanceMode) -> Void)?
    var onOpacityChange: ((Double) -> Void)?

    init(readmeDemoScene: ReadmeDemoScene? = nil) {
        self.readmeDemoScene = readmeDemoScene
    }
}

/// Manages the dropdown panel window: creation, show/hide animation,
/// edge-trigger coordination, and detached panel windows.
final class WindowManager {
    private var panel: DropDownPanel?
    
    private(set) var uiState: UIState
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
    private var revealView: PanelRevealView?
    private var revealState = PanelRevealState()

    init(persistence: PersistenceManager, clipboard: ClipboardMonitor, notes: NotesManager, files: FileStagingManager, todos: TodoManager, settings: AppSettings) {
        self.persistence = persistence
        self.clipboard = clipboard
        self.notes = notes
        self.files = files
        self.todos = todos
        self.settings = settings
        self.uiState = UIState(
            readmeDemoScene: ReadmeDemoLaunchMode.parse(arguments: CommandLine.arguments).scene
        )
        setupWindow()
        setupEdgeTracker()
        setupHotkey()
    }

    // MARK: - Setup

    private func setupWindow() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let height = settings.windowHeight
        let frame = dropdownPanelFrame(screenFrame: screen.frame, height: height)

        let panel = DropDownPanel(contentRect: frame)
        panel.alphaValue = CGFloat(settings.windowOpacity)
        panel.ignoresMouseEvents = true

        let content = MainContentView()
            .environment(clipboard)
            .environment(notes)
            .environment(files)
            .environment(todos)
            .environment(settings)
            .environment(uiState)

        let hostingController = NSHostingController(rootView: content)
        let revealController = PanelRevealViewController(hostedController: hostingController)
        panel.contentViewController = revealController

        self.revealView = revealController.revealView
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

    func updateOpacity(_ opacity: Double) {
        settings.windowOpacity = opacity
        panel?.alphaValue = CGFloat(opacity)
    }

    // MARK: - Show / Hide

    func toggle() {
        if uiState.isWindowVisible { hide() } else { show(source: .hotkey) }
    }

    func show(source: TopEdgeTracker.ShowSource = .hotkey) {
        guard !uiState.isWindowVisible else { return }
        guard let panel = panel, let screen = screenWithMouse() else { return }

        uiState.isWindowVisible = true
        edgeTracker.windowDidShow(source: source)

        let height = settings.windowHeight
        let targetFrame = dropdownPanelFrame(screenFrame: screen.frame, height: height)
        revealState.startOpening()
        panel.setFrame(targetFrame, display: false)
        panel.alphaValue = CGFloat(settings.windowOpacity)
        panel.orderFrontRegardless()
        animateReveal(to: 1)
    }

    func hide() {
        guard uiState.isWindowVisible else { return }
        guard panel != nil else { return }
        uiState.isWindowVisible = false
        edgeTracker.windowDidHide()
        revealState.startClosing()
        animateReveal(to: 0)
    }

    private func animateReveal(to target: CGFloat) {
        guard let panel, let revealView else { return }
        animationTimer?.invalidate()
        animationTimer = nil

        let animation = PanelRevealAnimation(
            from: revealState.progress,
            to: target,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        revealView.usesReveal = animation.usesReveal
        panel.ignoresMouseEvents = !ReadmeDemoPresentation.demoFramesAreInteractive

        guard animation.duration > 0 else {
            finishReveal(at: target)
            return
        }

        isAnimating = true
        let start = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = CGFloat(ProcessInfo.processInfo.systemUptime - start)
            self.revealState.update(progress: animation.progress(elapsed: elapsed))
            revealView.progress = self.revealState.progress
            if elapsed >= animation.duration {
                timer.invalidate()
                self.animationTimer = nil
                self.finishReveal(at: target)
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finishReveal(at target: CGFloat) {
        revealState.update(progress: target)
        revealView?.progress = revealState.progress
        isAnimating = false
        if !revealState.isOrderedIn {
            panel?.orderOut(nil)
        } else {
            panel?.ignoresMouseEvents = !revealState.acceptsMouseEvents
        }
    }

    func showDemoFrame(progress: CGFloat, scene: ReadmeDemoScene? = nil) {
        guard let panel, let revealView, let screen = NSScreen.main else { return }
        // Scene selection is presentational only; demo frames remain noninteractive.
        if let scene { uiState.readmeDemoScene = scene }
        let clampedProgress = min(1, max(0, progress))
        panel.setFrame(
            dropdownPanelFrame(screenFrame: screen.frame, height: settings.windowHeight),
            display: false
        )
        panel.alphaValue = 1
        panel.ignoresMouseEvents = true
        revealState.startOpening()
        revealState.update(progress: clampedProgress)
        revealView.usesReveal = true
        revealView.progress = clampedProgress
        panel.orderFrontRegardless()
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
        animationTimer?.invalidate()
        animationTimer = nil
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
