import Cocoa

/// Monitors the system pasteboard and maintains a persistent history of copied items.
@Observable
final class ClipboardMonitor {
    private(set) var items: [ClipboardItem] = []
    private(set) var favorites: [ClipboardItem] = []

    @ObservationIgnored private var lastChangeCount: Int = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let persistence: PersistenceManager
    @ObservationIgnored private var limit: Int
    @ObservationIgnored private var skipNext: Bool = false

    init(persistence: PersistenceManager, limit: Int = 500) {
        self.persistence = persistence
        self.limit = limit
        loadFromDisk()
    }

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.check()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setLimit(_ newLimit: Int) {
        limit = newLimit
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        saveToDisk()
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if skipNext {
            skipNext = false
            return
        }

        // Check for file URLs first
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                let item = ClipboardItem(type: .file, text: url.lastPathComponent, fileURL: url, timestamp: Date())
                insertItem(item)
            }
            return
        }

        // Check for images
        if let tiffData = pb.data(forType: .tiff), let nsImage = NSImage(data: tiffData) {
            let pngData = nsImage.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }
            let item = ClipboardItem(type: .image, text: "Image", imageData: pngData ?? tiffData, timestamp: Date())
            insertItem(item)
            return
        }

        // Text
        if let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Deduplicate consecutive identical text
            if items.first?.type == .text && items.first?.text == text {
                return
            }
            let item = ClipboardItem(type: .text, text: text, timestamp: Date())
            insertItem(item)
        }
    }

    private func insertItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        saveToDisk()
    }

    /// Put an item back onto the pasteboard for pasting.
    func copyToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case .text:
            pb.setString(item.text, forType: .string)
        case .image:
            if let data = item.imageData {
                if let image = NSImage(data: data) {
                    pb.clearContents()
                    pb.writeObjects([image])
                }
            }
        case .file:
            if let url = item.fileURL {
                pb.clearContents()
                pb.writeObjects([url as NSURL])
            }
        }
        skipNext = true
        lastChangeCount = pb.changeCount
    }

    func toggleFavorite(_ item: ClipboardItem) {
        if let idx = favorites.firstIndex(where: { $0.id == item.id }) {
            favorites.remove(at: idx)
        } else {
            var fav = item
            fav.isFavorite = true
            favorites.insert(fav, at: 0)
        }
        saveToDisk()
    }

    func isFavorite(_ item: ClipboardItem) -> Bool {
        favorites.contains(where: { $0.id == item.id })
    }

    func removeFromFavorites(_ item: ClipboardItem) {
        favorites.removeAll(where: { $0.id == item.id })
        saveToDisk()
    }

    func clearHistory() {
        items.removeAll()
        saveToDisk()
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll(where: { $0.id == item.id })
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        items = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_history")?.items ?? []
        favorites = persistence.load(ClipboardHistoryStore.self, forKey: "clipboard_favorites")?.items ?? []
    }

    private func saveToDisk() {
        persistence.save(ClipboardHistoryStore(items: items), forKey: "clipboard_history")
        persistence.save(ClipboardHistoryStore(items: favorites), forKey: "clipboard_favorites")
    }
}
