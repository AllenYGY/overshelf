import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

require(FileGridLayout.columnCount(for: 180) == 2, "narrow Files panels should use two columns")
require(FileGridLayout.columnCount(for: 240) == 3, "normal Files panels should use three columns")
require(FileGridLayout.columnCount(for: 900) == 3, "Files grids should stay capped at three columns")

print("File grid layout test passed")
