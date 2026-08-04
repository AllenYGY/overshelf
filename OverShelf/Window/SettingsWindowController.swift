import Cocoa
import SwiftUI

/// Owns the standalone preferences window. Using a dedicated floating
/// NSWindow (instead of the SwiftUI `Settings` scene) keeps it above the
/// dropdown panel and makes it reachable from Cmd-, / menu while the app is
/// an LSUIElement (accessory) app.
final class SettingsWindowController {
    private var window: NSWindow?

    func show(content: NSViewController) {
        if window == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            w.title = "OverShelf Preferences"
            w.isReleasedWhenClosed = false
            w.isExcludedFromWindowsMenu = true
            w.center()
            w.contentViewController = content
            window = w
        }
        window?.contentViewController = content
        window?.level = .floating
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
