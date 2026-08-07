import Foundation
import Cocoa
import SwiftUI

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-test-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let settingsURL = tempDir.appendingPathComponent("settings.json")
let oldJSON = """
{"edgeTriggerEnabled":true,"keepOnTop":true,"windowHeight":420,"hotkeyModifiers":1179648,"windowOpacity":0.73,"dragToEdgeEnabled":true,"panelOrder":["clipboard","files","notes"],"clipboardHistoryLimit":500,"panelWidths":["clipboard",260,"files",240,"notes",280],"hiddenPanels":[],"hotkeyCode":8}
"""
try? oldJSON.data(using: .utf8)!.write(to: settingsURL)

let persistence = PersistenceManager(baseURL: tempDir)
let settings = AppSettings(persistence: persistence)

guard let migratedData = try? Data(contentsOf: settingsURL),
      let migratedObj = try? JSONSerialization.jsonObject(with: migratedData) as? [String: Any],
      let order = migratedObj["panelOrder"] as? [String],
      order.contains("todo"),
      order.contains("workspaces"),
      migratedObj["appearanceMode"] as? String == "system",
      migratedObj["filesViewMode"] as? String == "list" else {
    fatalError("migration did not persist expected fields")
}

guard settings.appearanceMode == .system else {
    fatalError("legacy settings should default to the system appearance")
}
guard settings.windowOpacity == 0.73 else {
    fatalError("migration should preserve an existing window opacity")
}
guard settings.filesViewMode == .list else {
    fatalError("legacy settings should migrate Files to List view")
}

settings.filesViewMode = .icons
guard AppSettings(persistence: persistence).filesViewMode == .icons else {
    fatalError("Files view mode should persist across reload")
}

guard AppearanceMode.system.appKitName == nil,
      AppearanceMode.light.appKitName == .aqua,
      AppearanceMode.dark.appKitName == .darkAqua else {
    fatalError("appearance modes should map to the expected AppKit appearances")
}

guard settings.panelOrder.contains(.todo) else {
    fatalError("migration did not add Todo panel")
}

guard settings.panelOrder.contains(.workspaces) else {
    fatalError("migration did not add the Workspaces panel")
}

guard settings.panelWidths[.workspaces] != nil else {
    fatalError("migration did not assign a default Workspaces panel width")
}

guard settings.visiblePanels == [.clipboard, .files, .notes, .todo],
      settings.hiddenPanels.contains(.workspaces) else {
    fatalError("migration should preserve the four-panel default and keep Workspaces opt-in")
}

let reloadedSettings = AppSettings(persistence: persistence)
guard reloadedSettings.appearanceMode == .system,
      reloadedSettings.windowOpacity == 0.73 else {
    fatalError("migrated appearance and opacity should survive reload")
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

settings.panelOrder = [.todo, .clipboard, .files, .notes, .workspaces]
guard settings.visiblePanels == [.todo, .clipboard, .files, .notes] else {
    fatalError("panel reorder should preserve the hidden Workspaces preference")
}

hidden = settings.hiddenPanels
hidden.remove(.workspaces)
settings.hiddenPanels = hidden
guard settings.visiblePanels == [.todo, .clipboard, .files, .notes, .workspaces] else {
    fatalError("Workspaces should become visible when the user enables it")
}
guard !AppSettings(persistence: persistence).hiddenPanels.contains(.workspaces) else {
    fatalError("the user's Workspaces visibility choice should persist")
}

let newSettingsDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-new-settings-test-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: newSettingsDir, withIntermediateDirectories: true)
let newSettings = AppSettings(persistence: PersistenceManager(baseURL: newSettingsDir))
guard newSettings.windowOpacity == 1 else {
    fatalError("new settings should default to a fully opaque window")
}
guard newSettings.panelOrder == [.clipboard, .files, .notes, .todo, .workspaces] else {
    fatalError("new settings should include the Workspaces panel in the default order")
}
guard newSettings.visiblePanels == [.clipboard, .files, .notes, .todo],
      newSettings.hiddenPanels == [.workspaces] else {
    fatalError("new settings should default to the original four visible panels")
}

guard newSettings.filesViewMode == .list else {
    fatalError("new settings should default Files to List view")
}
print("Migration test passed: \(settings.panelOrder.map(\.rawValue).joined(separator: ", "))")
