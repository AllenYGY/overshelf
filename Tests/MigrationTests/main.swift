import Foundation
import Cocoa
import SwiftUI

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-test-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let settingsURL = tempDir.appendingPathComponent("settings.json")
let oldJSON = """
{"edgeTriggerEnabled":true,"keepOnTop":true,"windowHeight":420,"hotkeyModifiers":1179648,"windowOpacity":1,"dragToEdgeEnabled":true,"panelOrder":["clipboard","files","notes"],"clipboardHistoryLimit":500,"panelWidths":["clipboard",260,"files",240,"notes",280],"hiddenPanels":[],"hotkeyCode":8}
"""
try? oldJSON.data(using: .utf8)!.write(to: settingsURL)

let persistence = PersistenceManager(baseURL: tempDir)
let settings = AppSettings(persistence: persistence)

guard settings.panelOrder.contains(.todo) else {
    fatalError("migration did not add Todo panel")
}

guard settings.visiblePanels.count == 4, settings.visiblePanels.contains(.todo) else {
    fatalError("migration did not make all four panels visible")
}

guard let data = try? Data(contentsOf: settingsURL),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let order = obj["panelOrder"] as? [String],
      order.contains("todo") else {
    fatalError("migration did not persist Todo panel")
}

var hidden = settings.hiddenPanels
hidden.insert(.todo)
settings.hiddenPanels = hidden
guard settings.visiblePanels.contains(.todo) == false else {
    fatalError("hidden panel should disappear from visiblePanels")
}

hidden.remove(.todo)
settings.hiddenPanels = hidden
guard settings.visiblePanels.contains(.todo) else {
    fatalError("hidden panel should be restorable through visiblePanels")
}

settings.panelOrder = [.todo, .clipboard, .files, .notes]
guard settings.visiblePanels == [.todo, .clipboard, .files, .notes] else {
    fatalError("panel reorder did not persist through visiblePanels")
}

print("Migration test passed: \(settings.panelOrder.map(\.rawValue).joined(separator: ", "))")
