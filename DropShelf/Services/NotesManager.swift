import Foundation

/// Manages creation, editing, deletion, and search of quick notes.
@Observable
final class NotesManager {
    private(set) var notes: [Note] = []

    @ObservationIgnored private let persistence: PersistenceManager
    @ObservationIgnored private var saveTimer: Timer?

    init(persistence: PersistenceManager) {
        self.persistence = persistence
        loadFromDisk()
    }

    @discardableResult
    func createNote() -> Note {
        let note = Note(title: "Untitled", body: "")
        notes.insert(note, at: 0)
        scheduleSave()
        return note
    }

    func updateNote(id: UUID, body: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].body = body
        notes[idx].title = Note.deriveTitle(from: body)
        notes[idx].modifiedAt = Date()
        scheduleSave()
    }

    func togglePin(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].pinned.toggle()
        sortNotes()
        scheduleSave()
    }

    func deleteNote(id: UUID) {
        notes.removeAll(where: { $0.id == id })
        scheduleSave()
    }

    func search(_ query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.body.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func sortNotes() {
        notes.sort { a, b in
 if a.pinned != b.pinned { return a.pinned }
            return a.modifiedAt > b.modifiedAt
        }
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.saveToDisk()
        }
    }

    private func loadFromDisk() {
        notes = persistence.load(NotesStore.self, forKey: "notes")?.notes ?? []
        sortNotes()
    }

    private func saveToDisk() {
        sortNotes()
        persistence.save(NotesStore(notes: notes), forKey: "notes")
    }
}
