import Foundation
import Cocoa

func fail(_ message: String) -> Never {
    fputs("WORKSPACE TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-workspace-test-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let persistence = PersistenceManager(baseURL: tempDir)

// Creation
let manager = WorkspaceManager(persistence: persistence)
guard manager.workspaces.isEmpty else {
    fail("a fresh workspace manager should start empty")
}

let workspace = manager.createWorkspace(title: "Launch")
guard manager.workspaces.count == 1,
      manager.workspaces[0].id == workspace.id,
      manager.workspaces[0].title == "Launch" else {
    fail("createWorkspace should insert the new workspace")
}

// Rename
manager.renameWorkspace(id: workspace.id, title: "Release")
guard manager.workspaces[0].title == "Release" else {
    fail("renameWorkspace should update the title")
}

// Pinning one item of each supported kind
let clipID = UUID()
let fileID = UUID()
let noteID = UUID()
let todoID = UUID()
manager.pin(.clipboard, itemID: clipID, to: workspace.id)
manager.pin(.file, itemID: fileID, to: workspace.id)
manager.pin(.note, itemID: noteID, to: workspace.id)
manager.pin(.todo, itemID: todoID, to: workspace.id)

guard manager.isPinned(.clipboard, itemID: clipID, in: workspace.id),
      manager.isPinned(.file, itemID: fileID, in: workspace.id),
      manager.isPinned(.note, itemID: noteID, in: workspace.id),
      manager.isPinned(.todo, itemID: todoID, in: workspace.id) else {
    fail("pinning should record a reference for every item kind")
}
guard !manager.isPinned(.clipboard, itemID: UUID(), in: workspace.id) else {
    fail("unpinned items should not report as pinned")
}

// Pinning the same item twice must not duplicate the reference
manager.pin(.clipboard, itemID: clipID, to: workspace.id)
guard manager.workspaces[0].clipboardItemIDs == [clipID] else {
    fail("pinning the same item twice should not duplicate the reference")
}

// Persistence round-trip
manager.flush()
let reloaded = WorkspaceManager(persistence: persistence)
guard reloaded.workspaces.count == 1,
      reloaded.workspaces[0].title == "Release",
      reloaded.workspaces[0].clipboardItemIDs == [clipID],
      reloaded.workspaces[0].stagedFileIDs == [fileID],
      reloaded.workspaces[0].noteIDs == [noteID],
      reloaded.workspaces[0].todoIDs == [todoID] else {
    fail("workspaces should persist across reload")
}

// Unpinning removes only the reference
reloaded.unpin(.note, itemID: noteID, from: workspace.id)
guard !reloaded.isPinned(.note, itemID: noteID, in: workspace.id),
      reloaded.isPinned(.todo, itemID: todoID, in: workspace.id) else {
    fail("unpin should remove only that reference")
}

// Pruning drops references whose source item no longer exists
let ghostID = UUID()
reloaded.pin(.todo, itemID: ghostID, to: workspace.id)
reloaded.pruneMissingReferences(validIDs: [
    .clipboard: [clipID],
    .file: [fileID],
    .note: [],
    .todo: [todoID]
])
guard reloaded.workspaces[0].todoIDs == [todoID],
      reloaded.workspaces[0].clipboardItemIDs == [clipID],
      reloaded.workspaces[0].stagedFileIDs == [fileID] else {
    fail("pruning should remove ghost references and keep valid ones")
}

// Deleting a workspace
reloaded.deleteWorkspace(id: workspace.id)
guard reloaded.workspaces.isEmpty else {
    fail("deleteWorkspace should remove the workspace")
}
reloaded.flush()
guard WorkspaceManager(persistence: persistence).workspaces.isEmpty else {
    fail("workspace deletion should persist")
}

print("Workspace tests passed")
