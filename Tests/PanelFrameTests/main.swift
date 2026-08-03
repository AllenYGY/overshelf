import Foundation
import CoreGraphics

func fail(_ message: String) -> Never {
    fputs("PANEL FRAME TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let screen = CGRect(x: 100, y: 0, width: 1440, height: 900)
let height: CGFloat = 420
let frame = dropdownPanelFrame(screenFrame: screen, height: height)

guard frame.minX == screen.minX, frame.width == screen.width else {
    fail("panel should span the full screen width")
}
guard frame.minY == screen.maxY - height, frame.height == height else {
    fail("panel should sit at the bottom of the top edge")
}

print("Panel frame test passed")
