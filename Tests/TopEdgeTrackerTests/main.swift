import Foundation
import Cocoa
import SwiftUI

func fail(_ message: String) -> Never {
    fputs("TOP EDGE TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let tracker = TopEdgeTracker()
tracker.isEnabled = true

guard tracker.shouldShowAt(cmdHeld: true, mouseY: 1200, screenMaxY: 1200) else {
    fail("Cmd at top edge should show")
}
guard !tracker.shouldShowAt(cmdHeld: false, mouseY: 1200, screenMaxY: 1200) else {
    fail("Without Cmd the top edge should not show")
}
guard !tracker.shouldShowAt(cmdHeld: true, mouseY: 1199, screenMaxY: 1200) else {
    fail("Below top edge should not show")
}

tracker.isEnabled = false
guard !tracker.shouldShowAt(cmdHeld: true, mouseY: 1200, screenMaxY: 1200) else {
    fail("Disabled tracker should not show")
}

tracker.isEnabled = true
tracker.windowDidShow()
let panelFrame = NSRect(x: 0, y: 0, width: 800, height: 400)
guard !tracker.shouldHideOnClick(at: NSPoint(x: 400, y: 200), panelFrame: panelFrame) else {
    fail("Click inside panel should not hide")
}
guard tracker.shouldHideOnClick(at: NSPoint(x: 900, y: 200), panelFrame: panelFrame) else {
    fail("Click outside panel should hide")
}

print("Top edge tracker test passed")
