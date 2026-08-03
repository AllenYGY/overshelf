import Foundation

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
