import Foundation

/// The kind of source item a workspace reference points to.
enum WorkspaceItemKind: String, Codable, CaseIterable, Identifiable {
    case clipboard
    case file
    case note
    case todo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .file: return "Files"
        case .note: return "Notes"
        case .todo: return "Todo"
        }
    }

    var iconName: String {
        switch self {
        case .clipboard: return "clipboard"
        case .file: return "tray.full"
        case .note: return "note.text"
        case .todo: return "checklist"
        }
    }
}

/// A named collection of references to existing clipboard items, staged files,
/// notes, and todos. Workspaces store IDs only; they never copy the source data.
struct Workspace: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var modifiedAt: Date
    var clipboardItemIDs: [UUID]
    var stagedFileIDs: [UUID]
    var noteIDs: [UUID]
    var todoIDs: [UUID]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        clipboardItemIDs: [UUID] = [],
        stagedFileIDs: [UUID] = [],
        noteIDs: [UUID] = [],
        todoIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.clipboardItemIDs = clipboardItemIDs
        self.stagedFileIDs = stagedFileIDs
        self.noteIDs = noteIDs
        self.todoIDs = todoIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        clipboardItemIDs = (try c.decodeIfPresent([UUID].self, forKey: .clipboardItemIDs)) ?? []
        stagedFileIDs = (try c.decodeIfPresent([UUID].self, forKey: .stagedFileIDs)) ?? []
        noteIDs = (try c.decodeIfPresent([UUID].self, forKey: .noteIDs)) ?? []
        todoIDs = (try c.decodeIfPresent([UUID].self, forKey: .todoIDs)) ?? []
    }

    func ids(for kind: WorkspaceItemKind) -> [UUID] {
        switch kind {
        case .clipboard: return clipboardItemIDs
        case .file: return stagedFileIDs
        case .note: return noteIDs
        case .todo: return todoIDs
        }
    }

    var isEmpty: Bool {
        WorkspaceItemKind.allCases.allSatisfy { ids(for: $0).isEmpty }
    }
}

/// Wrapper for persisting workspaces.
struct WorkspacesStore: Codable {
    var workspaces: [Workspace]
}
