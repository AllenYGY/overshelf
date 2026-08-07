import Cocoa

func fail(_ message: String) -> Never {
    fputs("APP BUNDLE TEST FAIL: \(message)\n", stderr)
    exit(1)
}

guard let appPath = ProcessInfo.processInfo.environment["DROPSHELF_APP_BUNDLE"] else {
    fail("DROPSHELF_APP_BUNDLE is missing")
}

let infoURL = URL(fileURLWithPath: appPath)
    .appendingPathComponent("Contents/Info.plist")
guard let data = try? Data(contentsOf: infoURL),
      let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
      let dict = plist as? [String: Any] else {
    fail("Info.plist could not be read")
}

guard dict["LSUIElement"] as? Bool == true else {
    fail("LSUIElement is not true")
}
guard dict["CFBundleIconFile"] as? String == "AppIcon" else {
    fail("CFBundleIconFile is not AppIcon")
}

guard let sourceIconPath = ProcessInfo.processInfo.environment["DROPSHELF_APP_ICON_SOURCE"] else {
    fail("DROPSHELF_APP_ICON_SOURCE is missing")
}

func renderedPixels(at url: URL, size: Int = 256) -> Data? {
    guard let image = NSImage(contentsOf: url),
          let bitmap = NSBitmapImageRep(
              bitmapDataPlanes: nil,
              pixelsWide: size,
              pixelsHigh: size,
              bitsPerSample: 8,
              samplesPerPixel: 4,
              hasAlpha: true,
              isPlanar: false,
              colorSpaceName: .deviceRGB,
              bytesPerRow: 0,
              bitsPerPixel: 0
          ),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let bytes = bitmap.bitmapData else { return nil }
    return Data(bytes: bytes, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
}

let bundledIconURL = URL(fileURLWithPath: appPath)
    .appendingPathComponent("Contents/Resources/AppIcon.icns")
guard let bundledPixels = renderedPixels(at: bundledIconURL),
      let sourcePixels = renderedPixels(at: URL(fileURLWithPath: sourceIconPath)) else {
    fail("app icons could not be rendered for comparison")
}
guard bundledPixels.count == sourcePixels.count else {
    fail("rendered app icons have different byte counts")
}

var totalDifference = 0
var materiallyDifferentBytes = 0
for (bundled, source) in zip(bundledPixels, sourcePixels) {
    let difference = abs(Int(bundled) - Int(source))
    totalDifference += difference
    if difference > 8 {
        materiallyDifferentBytes += 1
    }
}
let averageDifference = Double(totalDifference) / Double(bundledPixels.count)
let differentRatio = Double(materiallyDifferentBytes) / Double(bundledPixels.count)
guard averageDifference < 2, differentRatio < 0.03 else {
    fail(
        "bundled AppIcon.icns does not match the source app icon " +
        "(average difference: \(averageDifference), materially different: \(differentRatio))"
    )
}

let requiredResources = [
    "Contents/Resources/AppIcon.icns",
    "Contents/Resources/Markdown/markdown.html",
    "Contents/Resources/Markdown/markdown-it/markdown-it.min.js",
    "Contents/Resources/Markdown/dompurify/purify.min.js",
    "Contents/Resources/Markdown/katex/katex.min.js",
    "Contents/Resources/Markdown/katex/auto-render.min.js"
]

for relative in requiredResources {
    let path = appPath + "/" + relative
    guard FileManager.default.fileExists(atPath: path) else {
        fail("missing resource \(relative)")
    }
}

print("App bundle test passed")
