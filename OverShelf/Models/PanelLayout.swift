import Foundation
import CoreGraphics

/// Pure layout math for the main panel row.
enum PanelLayout {
    /// Scale each panel's preferred width so the row fills the window edge to edge.
    /// Panels never shrink below `minWidth`; missing preferences share evenly.
    static func widths(
        for panels: [PanelType],
        preferred: [PanelType: CGFloat],
        totalWidth: CGFloat,
        minWidth: CGFloat
    ) -> [PanelType: CGFloat] {
        guard !panels.isEmpty, totalWidth > 0 else { return [:] }

        let fallback = totalWidth / CGFloat(panels.count)
        let effective = panels.map { max(1, preferred[$0] ?? fallback) }
        let preferredTotal = effective.reduce(0, +)
        let scale = totalWidth / preferredTotal

        var result: [PanelType: CGFloat] = [:]
        for (index, panel) in panels.enumerated() {
            result[panel] = max(minWidth, effective[index] * scale)
        }
        return result
    }
}
