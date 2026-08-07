import CoreGraphics

enum FileGridLayout {
    static let horizontalPadding: CGFloat = 16
    static let spacing: CGFloat = 8
    static let minimumTileWidth: CGFloat = 68

    static func columnCount(for panelWidth: CGFloat) -> Int {
        let contentWidth = max(0, panelWidth - horizontalPadding)
        let possible = Int((contentWidth + spacing) / (minimumTileWidth + spacing))
        return min(3, max(2, possible))
    }
}
