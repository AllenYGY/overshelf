import Foundation

/// Manages creation, editing, completion, and filtering of todo items.
@Observable
final class TodoManager {
    private(set) var items: [TodoItem] = []

    @ObservationIgnored private let persistence: PersistenceManager
    @ObservationIgnored private var saveTimer: Timer?

    init(persistence: PersistenceManager) {
        self.persistence = persistence
        loadFromDisk()
    }

    @discardableResult
    func createTodo(title: String = "") -> TodoItem {
        let todo = TodoItem(title: title)
        items.insert(todo, at: 0)
        scheduleSave()
        return todo
    }

    func updateTitle(id: UUID, title: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].title = title
        items[idx].modifiedAt = Date()
        scheduleSave()
    }

    func toggleCompletion(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isCompleted.toggle()
        items[idx].modifiedAt = Date()
        sortItems()
        scheduleSave()
    }

    func updatePriority(id: UUID, priority: TodoItem.Priority) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].priority = priority
        items[idx].modifiedAt = Date()
        sortItems()
        scheduleSave()
    }

    func updateDueDate(id: UUID, dueDate: Date?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].dueDate = dueDate
        items[idx].modifiedAt = Date()
        sortItems()
        scheduleSave()
    }

    func deleteTodo(id: UUID) {
        items.removeAll(where: { $0.id == id })
        scheduleSave()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        scheduleSave()
    }

    func search(_ query: String) -> [TodoItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var incompleteCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    private func sortItems() {
        items.sort { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            if a.priority != b.priority {
                return a.priority.sortOrder < b.priority.sortOrder
            }
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
        items = persistence.load(TodoStore.self, forKey: "todos")?.items ?? []
        sortItems()
    }

    private func saveToDisk() {
        sortItems()
        persistence.save(TodoStore(items: items), forKey: "todos")
    }
}

extension TodoItem.Priority {
    fileprivate var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}
