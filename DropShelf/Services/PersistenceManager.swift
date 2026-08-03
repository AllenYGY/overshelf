import Foundation

/// Handles loading and saving Codable data to Application Support.
final class PersistenceManager {
    private let fileManager = FileManager.default
    let appSupportURL: URL

    init(baseURL: URL? = nil) {
        if let baseURL {
            appSupportURL = baseURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            appSupportURL = base.appendingPathComponent("DropShelf", isDirectory: true)
        }
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let url = appSupportURL.appendingPathComponent("\(key).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Encodable>(_ value: T, forKey key: String) {
        let url = appSupportURL.appendingPathComponent("\(key).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
