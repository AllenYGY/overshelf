import Cocoa

/// Event-driven trigger: Cmd + mouse at top edge.
/// Uses global event monitors for instant response (no polling delay).
@Observable
final class TopEdgeTracker {
    enum ShowSource {
        case edge
        case hotkey
        case drag
    }

    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    var onDragToTop: (() -> Void)?
    var panelFrameProvider: (() -> NSRect)?

    var isEnabled: Bool = true
    var dragToTopEnabled: Bool = true

    @ObservationIgnored private var mouseMovedMonitor: Any?
    @ObservationIgnored private var flagsChangedMonitor: Any?
    @ObservationIgnored private var dragMonitor: Any?
    @ObservationIgnored private var clickMonitor: Any?
    @ObservationIgnored private var fallbackTimer: Timer?
    @ObservationIgnored private(set) var isWindowVisible = false
    @ObservationIgnored private var lastHideCheck: Date = .distantPast
    @ObservationIgnored private var showSource: ShowSource = .hotkey

    func start() {
        // Instant: fires when mouse moves anywhere
        mouseMovedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.checkTrigger()
        }

        // Instant: fires when Cmd (or any modifier) is pressed/released
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] _ in
            self?.checkTrigger()
        }

        // Click-outside auto-hide
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let mouse = NSEvent.mouseLocation
            let frame = self.panelFrameProvider?() ?? .zero
            if self.shouldHideOnClick(at: mouse, panelFrame: frame) {
                self.onHide?()
            }
        }

        // Drag-to-top (for file dragging)
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.handleDrag()
        }

        // Fallback timer (low frequency, events handle the rest)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.checkTrigger()
        }
        RunLoop.main.add(fallbackTimer!, forMode: .common)
    }

    func stop() {
        for monitor in [mouseMovedMonitor, flagsChangedMonitor, clickMonitor, dragMonitor] {
            if let m = monitor { NSEvent.removeMonitor(m) }
        }
        mouseMovedMonitor = nil
        flagsChangedMonitor = nil
        clickMonitor = nil
        dragMonitor = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }

    func windowDidShow(source: ShowSource = .hotkey) {
        isWindowVisible = true
        showSource = source
        lastHideCheck = Date()
    }
    func windowDidHide() { isWindowVisible = false }

    // MARK: - Screen helpers

    private func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouse) })
    }

    // Use visibleFrame.maxY (below menu bar) for reliable top-edge detection
    private func isMouseAtTopEdge() -> Bool {
        guard let screen = screenWithMouse() else { return false }
        return NSEvent.mouseLocation.y >= screen.visibleFrame.maxY
    }

    // MARK: - Drag-to-top

    private func handleDrag() {
        guard dragToTopEnabled, !isWindowVisible, isMouseAtTopEdge() else { return }
        onDragToTop?()
    }

    // MARK: - Trigger logic (called by events + fallback timer)

    func checkTrigger() {
        // Only handles SHOW — hide is via click-outside or hotkey toggle
        guard !isWindowVisible else { return }
        let cmdHeld = NSEvent.modifierFlags.contains(.command)
        if shouldShowAt(cmdHeld: cmdHeld, mouseY: NSEvent.mouseLocation.y, screenMaxY: screenWithMouse()?.visibleFrame.maxY ?? 0) {
            onShow?()
        }
    }

    /// Pure trigger predicate so the hot-zone logic can be unit tested.
    func shouldShowAt(cmdHeld: Bool, mouseY: CGFloat, screenMaxY: CGFloat) -> Bool {
        isEnabled && cmdHeld && mouseY >= screenMaxY
    }

    /// Pure click-outside predicate so the auto-hide behavior can be unit tested.
    func shouldHideOnClick(at mouse: NSPoint, panelFrame: NSRect) -> Bool {
        isWindowVisible && !panelFrame.contains(mouse)
    }
}
