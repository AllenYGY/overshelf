import Foundation

/// A file reference stored in the file staging area.
/// The actual file is not moved or copied; only a bookmark + URL reference are stored.
struct StagedFile: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bookmarkData: Data?
    var url: URL?
    let timestamp: Date

    init(id: UUID = UUID(), name: String, bookmarkData: Data? = nil, url: URL? = nil, timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
        self.url = url
        self.timestamp = timestamp
    }
}

/// Wrapper for persisting the staged files list.
struct StagedFilesStore: Codable {
    var files: [StagedFile]
}
