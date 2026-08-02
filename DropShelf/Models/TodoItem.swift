import Foundation

/// A single todo item.
struct TodoItem: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    let createdAt: Date
    var modifiedAt: Date

    enum Priority: String, Codable, CaseIterable, Identifiable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }

        var color: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Wrapper for persisting todos.
struct TodoStore: Codable {
    var items: [TodoItem]
}
