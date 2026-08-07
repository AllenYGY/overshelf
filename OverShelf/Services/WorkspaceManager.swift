import Foundation

/// Manages pinned workspaces: named, persisted collections of references to
/// existing clipboard items, staged files, notes, and todos.
@Observable
final class WorkspaceManager {
    private(set) var workspaces: [Workspace] = []

    @ObservationIgnored private let persistence: PersistenceManager
    @ObservationIgnored private var saveTimer: Timer?

    init(persistence: PersistenceManager) {
        self.persistence = persistence
        loadFromDisk()
    }

    @discardableResult
    func createWorkspace(title: String = "New Workspace") -> Workspace {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = Workspace(title: trimmed.isEmpty ? "New Workspace" : trimmed)
        workspaces.append(workspace)
        scheduleSave()
        return workspace
    }

    func renameWorkspace(id: UUID, title: String) {
        guard let idx = workspaces.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        workspaces[idx].title = trimmed
        workspaces[idx].modifiedAt = Date()
        scheduleSave()
    }

    func deleteWorkspace(id: UUID) {
        workspaces.removeAll(where: { $0.id == id })
        scheduleSave()
    }

    func pin(_ kind: WorkspaceItemKind, itemID: UUID, to workspaceID: UUID) {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        guard !workspaces[idx].ids(for: kind).contains(itemID) else { return }
        switch kind {
        case .clipboard: workspaces[idx].clipboardItemIDs.append(itemID)
        case .file: workspaces[idx].stagedFileIDs.append(itemID)
        case .note: workspaces[idx].noteIDs.append(itemID)
        case .todo: workspaces[idx].todoIDs.append(itemID)
        }
        workspaces[idx].modifiedAt = Date()
        scheduleSave()
    }

    func unpin(_ kind: WorkspaceItemKind, itemID: UUID, from workspaceID: UUID) {
        guard let idx = workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        switch kind {
        case .clipboard: workspaces[idx].clipboardItemIDs.removeAll { $0 == itemID }
        case .file: workspaces[idx].stagedFileIDs.removeAll { $0 == itemID }
        case .note: workspaces[idx].noteIDs.removeAll { $0 == itemID }
        case .todo: workspaces[idx].todoIDs.removeAll { $0 == itemID }
        }
        workspaces[idx].modifiedAt = Date()
        scheduleSave()
    }

    func isPinned(_ kind: WorkspaceItemKind, itemID: UUID, in workspaceID: UUID) -> Bool {
        workspaces.first(where: { $0.id == workspaceID })?.ids(for: kind).contains(itemID) ?? false
    }

    /// Drop references whose source item has been deleted from its owning panel.
    func pruneMissingReferences(validIDs: [WorkspaceItemKind: Set<UUID>]) {
        var changed = false
        for idx in workspaces.indices {
            for kind in WorkspaceItemKind.allCases {
                let valid = validIDs[kind] ?? []
                let before = workspaces[idx].ids(for: kind).count
                switch kind {
                case .clipboard: workspaces[idx].clipboardItemIDs.removeAll { !valid.contains($0) }
                case .file: workspaces[idx].stagedFileIDs.removeAll { !valid.contains($0) }
                case .note: workspaces[idx].noteIDs.removeAll { !valid.contains($0) }
                case .todo: workspaces[idx].todoIDs.removeAll { !valid.contains($0) }
                }
                if workspaces[idx].ids(for: kind).count != before {
                    changed = true
                }
            }
        }
        if changed {
            scheduleSave()
        }
    }

    func flush() {
        saveTimer?.invalidate()
        saveTimer = nil
        saveToDisk()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveToDisk()
        }
    }

    private func loadFromDisk() {
        workspaces = persistence.load(WorkspacesStore.self, forKey: "workspaces")?.workspaces ?? []
    }

    private func saveToDisk() {
        persistence.save(WorkspacesStore(workspaces: workspaces), forKey: "workspaces")
    }
}
