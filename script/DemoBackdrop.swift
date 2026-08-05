import AppKit

final class DemoBackdropDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NSScreen.main else {
            NSApp.terminate(nil)
            return
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = NSColor(calibratedWhite: 0.075, alpha: 1)
        window.level = .normal
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.orderFrontRegardless()
        self.window = window
    }
}

let app = NSApplication.shared
let delegate = DemoBackdropDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
