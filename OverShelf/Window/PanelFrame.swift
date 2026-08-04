import CoreGraphics

/// Returns the full-width frame for the dropdown panel on a given screen.
func dropdownPanelFrame(screenFrame: CGRect, height: CGFloat) -> CGRect {
    CGRect(x: screenFrame.minX, y: screenFrame.maxY - height, width: screenFrame.width, height: height)
}
