import SwiftUI

/// The file staging panel: drag files in, drag them out to any app or Finder.
struct FilesPanelView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(FileStagingManager.self) private var files

    @State private var isDropTargeted = false
    @State private var hoveredFile: UUID?

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Files",
                iconName: "tray.full"
            ) {
                Picker("File view", selection: Binding(
                    get: { settings.filesViewMode },
                    set: { settings.filesViewMode = $0 }
                )) {
                    Image(systemName: "list.bullet").tag(FilesViewMode.list).help("View as List")
                    Image(systemName: "square.grid.2x2").tag(FilesViewMode.icons).help("View as Icons")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.mini)
                .frame(width: 54)
            }

            if files.stagedFiles.isEmpty {
                emptyState
            } else {
                fileCollection
            }

            // Footer
            HStack {
                Text("\(files.stagedFiles.count) files")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !files.stagedFiles.isEmpty {
                    Button("Clear") { files.clear() }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.sidebarBg)
        }
        .background(isDropTargeted ? Theme.panelBg.opacity(0.6) : Theme.panelBg)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor.opacity(isDropTargeted ? 0.6 : 0), lineWidth: 2)
                .padding(2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
            return true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Drag files here")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("Files are referenced, not moved")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var fileCollection: some View {
        switch settings.filesViewMode {
        case .list: fileList
        case .icons: fileGrid
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(files.stagedFiles) { file in
                    FileRow(
                        file: file,
                        isHovered: hoveredFile == file.id,
                        onReveal: { revealFile(file) },
                        onRemove: { files.remove(id: file.id) }
                    )
                    .onHover { hoveredFile = $0 ? file.id : nil }
                    Divider()
                }
            }
        }
    }

    private var fileGrid: some View {
        GeometryReader { geometry in
            ScrollView {
                let columnCount = FileGridLayout.columnCount(for: geometry.size.width)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(files.stagedFiles) { file in
                        FileIconTile(
                            file: file,
                            isHovered: hoveredFile == file.id,
                            onReveal: { revealFile(file) },
                            onRemove: { files.remove(id: file.id) }
                        )
                        .onHover { hoveredFile = $0 ? file.id : nil }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        files.add(url: url)
                    }
                } else if let data = item as? Data {
                    if let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            files.add(url: url)
                        }
                    }
                }
            }
        }
    }

    private func revealFile(_ file: StagedFile) {
        guard let url = files.resolveURL(for: file) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

/// A single file row in the staging area.
struct FileRow: View {
    let file: StagedFile
    let isHovered: Bool
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // File icon (drag provider)
            if let url = file.url, let icon = NSWorkspace.shared.icon(forFile: url.path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Text(file.timestamp, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reveal button
            Button(action: onReveal) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Show in Finder") { onReveal() }
            Divider()
            Button("Remove") { onRemove() }
                .foregroundStyle(.red)
        }
        // Allow dragging the file out
        .onDrag {
            guard let url = file.url else { return NSItemProvider() }
            return NSItemProvider(object: url as NSURL)
        }
    }
}

/// A fixed-height icon tile for the Files grid.
struct FileIconTile: View {
    let file: StagedFile
    let isHovered: Bool
    let onReveal: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            iconView
                .frame(width: 44, height: 44)
            Text(file.name)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
        }
        .frame(height: 86)
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .overlay(
            Button(action: onReveal) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Theme.sidebarBg.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
            .opacity(isHovered ? 1 : 0)
            .padding(4),
            alignment: .topTrailing
        )
        .contextMenu {
            Button("Show in Finder", action: onReveal)
            Divider()
            Button("Remove", action: onRemove)
                .foregroundStyle(.red)
        }
        .onDrag {
            guard let url = file.url else { return NSItemProvider() }
            return NSItemProvider(object: url as NSURL)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let url = file.url {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "doc")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }
}
