import Foundation

enum ReadmeDemoScene: String, CaseIterable {
    case clipboard
    case files
    case notes
    case todo
    case overview

}

enum ReadmeDemoLaunchMode: Equatable {
    case normal
    case scene(ReadmeDemoScene)
    case invalidScene

    static func parse(arguments: [String]) -> ReadmeDemoLaunchMode {
        let prefix = "--readme-demo-scene="
        guard let argument = arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return .normal
        }
        guard let scene = ReadmeDemoScene(rawValue: String(argument.dropFirst(prefix.count))) else {
            return .invalidScene
        }
        return .scene(scene)
    }

    var isDemo: Bool {
        if case .normal = self { return false }
        return true
    }

    var scene: ReadmeDemoScene? {
        guard case let .scene(scene) = self else { return nil }
        return scene
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
                    dueDate: baseDate.addingTimeInterval(2 * 86_400),
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(180)
                ),
                TodoItem(
                    title: "Publish the build",
                    priority: .medium,
                    dueDate: baseDate.addingTimeInterval(4 * 86_400),
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(120)
                ),
                TodoItem(
                    title: "Update Homebrew",
                    isCompleted: true,
                    priority: .low,
                    dueDate: baseDate.addingTimeInterval(6 * 86_400),
                    createdAt: baseDate,
                    modifiedAt: baseDate.addingTimeInterval(60)
                )
            ]),
            forKey: "todos"
        )

        _ = scene
    }
}

/// Pure presentation rules shared by demo views and window framing.
enum ReadmeDemoPresentation {
    static let demoFramesAreInteractive = false

    static func startsNotesPreview(scene: ReadmeDemoScene?) -> Bool {
        scene == .notes || scene == .overview
    }
}
