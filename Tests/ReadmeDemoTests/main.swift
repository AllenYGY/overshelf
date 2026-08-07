import Foundation

func fail(_ message: String) -> Never {
    fputs("README DEMO TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let normalMode = ReadmeDemoLaunchMode.parse(arguments: ["OverShelf"])
guard normalMode == .normal, !normalMode.isDemo, normalMode.scene == nil else {
    fail("missing scene argument should use normal launch mode")
}

let notesMode = ReadmeDemoLaunchMode.parse(arguments: ["OverShelf", "--readme-demo-scene=notes"])
guard notesMode == .scene(.notes), notesMode.isDemo, notesMode.scene == .notes else {
    fail("notes scene argument was not parsed")
}

for scene in ReadmeDemoScene.allCases {
    let mode = ReadmeDemoLaunchMode.parse(arguments: ["OverShelf", "--readme-demo-scene=\(scene.rawValue)"])
    guard mode == .scene(scene) else {
        fail("scene argument did not parse for \(scene.rawValue)")
    }
}

guard ReadmeDemoPresentation.startsNotesPreview(scene: .notes),
      ReadmeDemoPresentation.startsNotesPreview(scene: .overview),
      !ReadmeDemoPresentation.startsNotesPreview(scene: .clipboard),
      !ReadmeDemoPresentation.startsNotesPreview(scene: nil),
      !ReadmeDemoPresentation.demoFramesAreInteractive else {
    fail("demo presentation contract did not preserve scene setup or noninteractive frames")
}

let invalidMode = ReadmeDemoLaunchMode.parse(
    arguments: ["OverShelf", "--readme-demo-scene=notse"]
)
guard invalidMode == .invalidScene, invalidMode.isDemo, invalidMode.scene == nil else {
    fail("invalid scene argument must remain in isolated demo mode")
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-readme-demo-test-\(UUID().uuidString)")
defer { try? FileManager.default.removeItem(at: tempDir) }

let persistence = PersistenceManager(baseURL: tempDir)
ReadmeDemoData.seed(scene: .overview, into: persistence)

guard let clipboard = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_history"),
      clipboard.items.map(\.text) == [
          "https://overshelf.app/docs",
          "#1F6FEB",
          "Review the launch checklist"
      ] else {
    fail("seeded clipboard text did not match the fixture")
}

guard let favorites = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_favorites"),
      favorites.items.count == 1,
      favorites.items[0].id == clipboard.items[1].id,
      favorites.items[0].isFavorite,
      clipboard.items[1].isFavorite else {
    fail("seeded favorite did not preserve clipboard item identity")
}

guard let files = persistence.load(StagedFilesStore.self, forKey: "staged_files"),
      files.files.map(\.name) == ["Launch-Brief.pdf", "App-Icon.sketch"],
      files.files.compactMap(\.url?.path) == [
          "/tmp/OverShelf-ReadmeDemo/Launch-Brief.pdf",
          "/tmp/OverShelf-ReadmeDemo/App-Icon.sketch"
      ] else {
    fail("seeded staged-file references did not match the fixture")
}

guard let notes = persistence.load(NotesStore.self, forKey: "notes"),
      notes.notes.count == 1,
      notes.notes[0].title == "Launch notes",
      notes.notes[0].pinned,
      notes.notes[0].body == """
      # Launch notes

      - [x] Review the launch checklist
      - [ ] Publish the build
      - [ ] Update Homebrew
      """ else {
    fail("seeded Launch notes Markdown did not match the fixture")
}

guard let todos = persistence.load(TodoStore.self, forKey: "todos"),
      todos.items.map(\.title) == ["Polish the README", "Publish the build", "Update Homebrew"],
      todos.items.map(\.priority) == [.high, .medium, .low],
      todos.items.map(\.dueDate) == [
          Date(timeIntervalSince1970: 1_753_689_600 + 2 * 86_400),
          Date(timeIntervalSince1970: 1_753_689_600 + 4 * 86_400),
          Date(timeIntervalSince1970: 1_753_689_600 + 6 * 86_400)
      ],
      todos.items.contains(where: { $0.isCompleted }) else {
    fail("seeded todos did not match the fixture")
}

guard let workspaces = persistence.load(WorkspacesStore.self, forKey: "workspaces"),
      workspaces.workspaces.count == 1,
      workspaces.workspaces[0].title == "Launch",
      workspaces.workspaces[0].clipboardItemIDs == [clipboard.items[1].id],
      workspaces.workspaces[0].stagedFileIDs == [files.files[0].id],
      workspaces.workspaces[0].noteIDs == [notes.notes[0].id],
      workspaces.workspaces[0].todoIDs == [todos.items[0].id] else {
    fail("seeded workspace should reference one item from each panel")
}

print("Readme demo tests passed")
