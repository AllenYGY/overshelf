import SwiftUI

/// The clipboard history panel: shows recent + favorites, search, click-to-paste.
struct ClipboardPanelView: View {
    @Environment(ClipboardMonitor.self) private var clipboard

    @State private var searchText = ""
    @State private var showFavorites = false

    var filteredItems: [ClipboardItem] {
        let source = showFavorites ? clipboard.favorites : clipboard.items
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return source }
        return source.filter { $0.displayText.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Clipboard",
                iconName: "clipboard"
            )

            // Tab switcher
            Picker("", selection: $showFavorites) {
                Text("Recent").tag(false)
                Text("Favorites").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.top, 6)

            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search clipboard", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Theme.fieldBg)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // List
            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            ClipboardRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    clipboard.copyToPasteboard(item)
                                }
                                .contextMenu {
                                    Button("Copy") { clipboard.copyToPasteboard(item) }
                                    if showFavorites {
                                        Button("Remove from favorites") {
                                            clipboard.removeFromFavorites(item)
                                        }
                                    } else {
                                        Button(showFavorites ? "Remove from favorites" : "Add to favorites") {
                                            if clipboard.isFavorite(item) {
                                                clipboard.removeFromFavorites(item)
                                            } else {
                                                clipboard.toggleFavorite(item)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button("Delete") { clipboard.deleteItem(item) }
                                        .foregroundStyle(.red)
                                }
                            Divider()
                        }
                    }
                }
            }

            // Footer
            HStack {
                Text("\(clipboard.items.count) items")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !showFavorites {
                    Button("Clear") { clipboard.clearHistory() }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .help("Clear all history")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.sidebarBg)
        }
        .background(Theme.panelBg)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: showFavorites ? "star" : "clipboard")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(showFavorites ? "No favorites yet" : "Nothing copied yet")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

/// A single clipboard history row.
struct ClipboardRow: View {
    let item: ClipboardItem
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Type icon / image preview
            Group {
                switch item.type {
                case .text:
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                case .image:
                    if let data = item.imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                case .file:
                    if let url = item.fileURL {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "doc")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 28, height: 28)

            // Text preview
            VStack(alignment: .leading, spacing: 1) {
                Text(item.previewText)
                    .font(.system(size: 12))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                Text(item.timestamp, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .onHover { isHovered = $0 }
    }
}
