import Foundation

/// A quick note with searchable text content.
struct Note: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var body: String
    let timestamp: Date
    var modifiedAt: Date
    var pinned: Bool

    init(id: UUID = UUID(), title: String = "", body: String = "", timestamp: Date = Date(), modifiedAt: Date = Date(), pinned: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.timestamp = timestamp
        self.modifiedAt = modifiedAt
        self.pinned = pinned
    }

    /// Derive a title from the first non-empty line of body.
    static func deriveTitle(from body: String) -> String {
        let firstLine = body.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        var trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        // Strip Markdown heading markers so the list shows "Title" instead of "# Title".
        while trimmed.hasPrefix("#") {
            trimmed.removeFirst()
            if trimmed.hasPrefix(" ") {
                trimmed.removeFirst()
            }
        }
        trimmed = trimmed.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(60))
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = (try c.decodeIfPresent(String.self, forKey: .body)) ?? ""
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        modifiedAt = try c.decode(Date.self, forKey: .modifiedAt)
        pinned = (try c.decodeIfPresent(Bool.self, forKey: .pinned)) ?? false
    }
}

/// Wrapper for persisting notes.
struct NotesStore: Codable {
    var notes: [Note]
}
