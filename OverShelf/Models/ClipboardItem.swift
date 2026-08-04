import Foundation

/// A single entry in clipboard history.
struct ClipboardItem: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let type: ItemType
    var text: String
    var imageData: Data?
    var fileURL: URL?
    let timestamp: Date
    var isFavorite: Bool

    enum ItemType: String, Codable {
        case text
        case image
        case file
    }

    var displayText: String {
        switch type {
        case .text:
            return text
        case .image:
            return text.isEmpty ? "Image" : text
        case .file:
            return fileURL?.lastPathComponent ?? text
        }
    }

    var previewText: String {
        let t = displayText
        return t.count > 200 ? String(t.prefix(200)) + "..." : t
    }

    init(id: UUID = UUID(), type: ItemType, text: String = "", imageData: Data? = nil, fileURL: URL? = nil, timestamp: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.type = type
        self.text = text
        self.imageData = imageData
        self.fileURL = fileURL
        self.timestamp = timestamp
        self.isFavorite = isFavorite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(ItemType.self, forKey: .type)
        text = try c.decode(String.self, forKey: .text)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        fileURL = try c.decodeIfPresent(URL.self, forKey: .fileURL)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}

/// Wrapper for persisting arrays of clipboard items.
struct ClipboardHistoryStore: Codable {
    var items: [ClipboardItem]
}
