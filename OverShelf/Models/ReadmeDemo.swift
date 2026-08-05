import Foundation

enum ReadmeDemoScene: String, CaseIterable {
    case clipboard
    case files
    case notes
    case todo
    case overview

    static func parse(arguments: [String]) -> ReadmeDemoScene? {
        let prefix = "--readme-demo-scene="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        return ReadmeDemoScene(rawValue: String(argument.dropFirst(prefix.count)))
    }
}

enum ReadmeDemoData {
    static func seed(scene: ReadmeDemoScene, into persistence: PersistenceManager) {
        let baseDate = Date(timeIntervalSince1970: 1_753_689_600)
        let clipboardItems = [
            ClipboardItem(
                type: .text,
                text: "https://overshelf.app/docs",
                timestamp: baseDate.addingTimeInterval(180)
            ),
            ClipboardItem(
                type: .text,
                text: "#1F6FEB",
                timestamp: baseDate.addingTimeInterval(120),
                isFavorite: true
            ),
            ClipboardItem(
                type: .text,
                text: "Review the launch checklist",
                timestamp: baseDate.addingTimeInterval(60)
            )
        ]
        persistence.save(ClipboardHistoryStore(items: clipboardItems), forKey: "clipboard_history")
        persistence.save(
            ClipboardHistoryStore(items: [clipboardItems[1]]),
            forKey: "clipboard_favorites"
        )

        let demoDirectory = URL(fileURLWithPath: "/tmp/OverShelf-ReadmeDemo", isDirectory: true)
        persistence.save(
            StagedFilesStore(files: [
                StagedFile(
                    name: "Launch-Brief.pdf",
                    url: demoDirectory.appendingPathComponent("Launch-Brief.pdf"),
                    timestamp: baseDate.addingTimeInterval(120)
                ),
                StagedFile(
                    name: "App-Icon.sketch",
                    url: demoDirectory.appendingPathComponent("App-Icon.sketch"),
                    timestamp: baseDate.addingTimeInterval(60)
                )
            ]),
            forKey: "staged_files"
        )

        let noteBody = """
        # Launch notes

        - [x] Review the launch checklist
        - [ ] Publish the build
        - [ ] Update Homebrew
        """
        persistence.save(
            NotesStore(notes: [
                Note(
                    title: "Launch notes",
                    body: noteBody,
                    timestamp: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(180),
                    pinned: true
                )
            ]),
            forKey: "notes"
        )

        persistence.save(
            TodoStore(items: [
                TodoItem(
                    title: "Polish the README",
                    priority: .high,
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(180)
                ),
                TodoItem(
                    title: "Publish the build",
                    priority: .medium,
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(120)
                ),
                TodoItem(
                    title: "Update Homebrew",
                    isCompleted: true,
                    priority: .low,
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(60)
                )
            ]),
            forKey: "todos"
        )

        _ = scene
    }
}
