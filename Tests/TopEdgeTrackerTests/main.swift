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

// Drag-to-top only triggers when the drag started below the top edge,
// filtering out accidental menu-bar icon drags.
guard tracker.shouldTriggerDrag(dragStartY: 500, mouseY: 1200, screenMaxY: 1200) else {
    fail("Drag from below top edge into it should trigger")
}
guard !tracker.shouldTriggerDrag(dragStartY: 1200, mouseY: 1200, screenMaxY: 1200) else {
    fail("Drag starting in the menu bar should not trigger")
}
guard !tracker.shouldTriggerDrag(dragStartY: 500, mouseY: 1199, screenMaxY: 1200) else {
    fail("Drag not yet reaching the top edge should not trigger")
}

print("Top edge tracker test passed")
