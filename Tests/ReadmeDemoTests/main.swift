import Foundation

func fail(_ message: String) -> Never {
    fputs("README DEMO TEST FAIL: \(message)\n", stderr)
    exit(1)
}

guard ReadmeDemoScene.parse(arguments: ["OverShelf", "--readme-demo-scene=notes"]) == .notes else {
    fail("notes scene argument was not parsed")
}

guard ReadmeDemoScene.parse(arguments: ["OverShelf"]) == nil else {
    fail("missing scene argument should not enable demo mode")
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-readme-demo-test-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: tempDir) }

let persistence = PersistenceManager(baseURL: tempDir)
ReadmeDemoData.seed(scene: .overview, into: persistence)

guard let clipboard = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_history"),
      clipboard.items.count == 3 else {
    fail("expected 3 seeded clipboard items")
}

guard let favorites = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_favorites"),
      favorites.items.count == 1,
      favorites.items.first?.isFavorite == true else {
    fail("expected one seeded clipboard favorite")
}

guard let files = persistence.load(StagedFilesStore.self, forKey: "staged_files"),
      files.files.count == 2 else {
    fail("expected 2 seeded staged files")
}

guard let notes = persistence.load(NotesStore.self, forKey: "notes"),
      notes.notes.count == 1,
      notes.notes[0].body.contains("# Launch notes") else {
    fail("expected a seeded Launch notes Markdown note")
}

guard let todos = persistence.load(TodoStore.self, forKey: "todos"),
      todos.items.count == 3,
      todos.items.contains(where: { $0.isCompleted }) else {
    fail("expected 3 seeded todos with at least one completed")
}

print("Readme demo tests passed")
