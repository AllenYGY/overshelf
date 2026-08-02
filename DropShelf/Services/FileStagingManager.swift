import Cocoa

/// Manages the file staging area: files are referenced, not moved.
@Observable
final class FileStagingManager {
    private(set) var stagedFiles: [StagedFile] = []

    @ObservationIgnored private let persistence: PersistenceManager

    init(persistence: PersistenceManager) {
        self.persistence = persistence
        loadFromDisk()
    }

    func add(url: URL) {
        // Resolve aliases/symlinks first
        let resolved = url.resolvingSymlinksInPath()
        let name = resolved.lastPathComponent

        var bookmarkData: Data? = nil
        do {
            bookmarkData = try resolved.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            bookmarkData = nil
        }

        // Avoid duplicates by URL
        if stagedFiles.contains(where: { $0.url == resolved || $0.name == name }) {
            return
        }

        let file = StagedFile(name: name, bookmarkData: bookmarkData, url: resolved)
        stagedFiles.append(file)
        saveToDisk()
    }

    func remove(id: UUID) {
        stagedFiles.removeAll(where: { $0.id == id })
        saveToDisk()
    }

    func clear() {
        stagedFiles.removeAll()
        saveToDisk()
    }

    /// Resolve a staged file to a usable URL, refreshing stale bookmarks.
    func resolveURL(for file: StagedFile) -> URL? {
        if let url = file.url {
            return url
        }
        guard let data = file.bookmarkData else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale, let idx = stagedFiles.firstIndex(where: { $0.id == file.id }) {
            stagedFiles[idx].url = url
            if let newBookmark = try? url.bookmarkData() {
                stagedFiles[idx].bookmarkData = newBookmark
            }
            saveToDisk()
        }
        return url
    }

    /// Get the file icon for display.
    func icon(for file: StagedFile) -> NSImage? {
        guard let url = resolveURL(for: file) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        stagedFiles = persistence.load(StagedFilesStore.self, forKey: "staged_files")?.files ?? []
        // Try to resolve URLs at load time
        for i in stagedFiles.indices {
            _ = resolveURL(for: stagedFiles[i])
        }
    }

    private func saveToDisk() {
        persistence.save(StagedFilesStore(files: stagedFiles), forKey: "staged_files")
    }
}
