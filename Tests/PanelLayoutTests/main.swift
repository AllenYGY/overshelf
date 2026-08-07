import Foundation
import CoreGraphics

func fail(_ message: String) -> Never {
    fputs("PANEL LAYOUT TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let panels: [PanelType] = [.clipboard, .files]

// Preferred widths scale proportionally to fill the window edge to edge.
let filled = PanelLayout.widths(
    for: panels,
    preferred: [.clipboard: 260, .files: 240],
    totalWidth: 1000,
    minWidth: 160
)
guard abs((filled[.clipboard] ?? 0) - 520) < 0.5,
      abs((filled[.files] ?? 0) - 480) < 0.5 else {
    fail("preferred widths should scale proportionally to fill the total width")
}
guard abs((filled[.clipboard] ?? 0) + (filled[.files] ?? 0) - 1000) < 0.5 else {
    fail("panel widths should sum to the total width so the last panel reaches the screen edge")
}

// Missing preferences fall back to an even share.
let fallback = PanelLayout.widths(
    for: [.clipboard, .todo],
    preferred: [:],
    totalWidth: 500,
    minWidth: 160
)
guard abs((fallback[.clipboard] ?? 0) - 250) < 0.5,
      abs((fallback[.todo] ?? 0) - 250) < 0.5 else {
    fail("panels without stored widths should share the total width evenly")
}

// Very narrow totals clamp each panel to the minimum width.
let clamped = PanelLayout.widths(
    for: panels,
    preferred: [.clipboard: 260, .files: 240],
    totalWidth: 300,
    minWidth: 160
)
guard clamped[.clipboard] == 160, clamped[.files] == 160 else {
    fail("panel widths should never drop below the minimum width")
}

print("Panel layout tests passed")
