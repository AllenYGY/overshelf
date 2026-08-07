import SwiftUI

/// The pinned workspaces panel: named collections of references to items
/// from the other panels. Workspaces store IDs only and never copy data.
struct WorkspacesPanelView: View {
    @Environment(WorkspaceManager.self) private var workspaces
    @Environment(ClipboardMonitor.self) private var clipboard
    @Environment(FileStagingManager.self) private var files
    @Environment(NotesManager.self) private var notes
    @Environment(TodoManager.self) private var todos

    @State private var selectedWorkspaceID: UUID?
    @State private var isRenaming = false
    @State private var renameText = ""

    private var selectedWorkspace: Workspace? {
        if let id = selectedWorkspaceID,
           let workspace = workspaces.workspaces.first(where: { $0.id == id }) {
            return workspace
        }
        return workspaces.workspaces.first
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: "Workspaces", iconName: "pin.square")

            if workspaces.workspaces.isEmpty {
                emptyState
            } else {
                workspaceToolbar
                if let workspace = selectedWorkspace {
                    workspaceContent(workspace)
                }
            }
        }
        .background(Theme.panelBg)
        .onAppear(perform: pruneMissingReferences)
        .onChange(of: clipboard.items) { _, _ in pruneMissingReferences() }
        .onChange(of: clipboard.favorites) { _, _ in pruneMissingReferences() }
        .onChange(of: files.stagedFiles) { _, _ in pruneMissingReferences() }
        .onChange(of: notes.notes) { _, _ in pruneMissingReferences() }
        .onChange(of: todos.items) { _, _ in pruneMissingReferences() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "pin.square")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No workspaces yet")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text("Pin clipboard items, files, notes, and todos into one focused collection.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("New Workspace") { createWorkspace() }
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    private var workspaceToolbar: some View {
        HStack(spacing: 6) {
            if isRenaming, selectedWorkspace != nil {
                TextField("Workspace name", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.fieldBg)
                    .cornerRadius(6)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Menu {
                    ForEach(workspaces.workspaces) { workspace in
                        Button {
                            selectedWorkspaceID = workspace.id
                        } label: {
                            Label(
                                workspace.title,
                                systemImage: workspace.id == selectedWorkspace?.id ? "checkmark" : "minus"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedWorkspace?.title ?? "Select")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Theme.fieldBg)
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }

            Button { createWorkspace() } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("New workspace")

            Menu {
                Button("Rename") { beginRename() }
                Divider()
                Button("Delete", role: .destructive) { deleteSelected() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Workspace actions")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Content

    private func workspaceContent(_ workspace: Workspace) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                clipboardSection(workspace)
                filesSection(workspace)
                notesSection(workspace)
                todosSection(workspace)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func clipboardSection(_ workspace: Workspace) -> some View {
        let items = workspace.clipboardItemIDs.compactMap { id in
            clipboard.items.first(where: { $0.id == id }) ?? clipboard.favorites.first(where: { $0.id == id })
        }
        return section(kind: .clipboard, count: items.count, addMenu: {
            addMenu(kind: .clipboard, workspace: workspace, candidates: clipboard.items.filter {
                !workspace.clipboardItemIDs.contains($0.id)
            }.map { (id: $0.id, label: $0.previewText) })
        }, rows: {
            ForEach(items) { item in
                WorkspaceRow(
                    icon: "text.alignleft",
                    title: item.previewText,
                    subtitle: nil,
                    onOpen: { clipboard.copyToPasteboard(item) },
                    onUnpin: { workspaces.unpin(.clipboard, itemID: item.id, from: workspace.id) }
                )
            }
        })
    }

    private func filesSection(_ workspace: Workspace) -> some View {
        let items = workspace.stagedFileIDs.compactMap { id in
            files.stagedFiles.first(where: { $0.id == id })
        }
        return section(kind: .file, count: items.count, addMenu: {
            addMenu(kind: .file, workspace: workspace, candidates: files.stagedFiles.filter {
                !workspace.stagedFileIDs.contains($0.id)
            }.map { (id: $0.id, label: $0.name) })
        }, rows: {
            ForEach(items) { file in
                WorkspaceRow(
                    icon: "doc",
                    title: file.name,
                    subtitle: nil,
                    onOpen: {
                        if let url = files.resolveURL(for: file) {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    },
                    onUnpin: { workspaces.unpin(.file, itemID: file.id, from: workspace.id) }
                )
            }
        })
    }

    private func notesSection(_ workspace: Workspace) -> some View {
        let items = workspace.noteIDs.compactMap { id in
            notes.notes.first(where: { $0.id == id })
        }
        return section(kind: .note, count: items.count, addMenu: {
            addMenu(kind: .note, workspace: workspace, candidates: notes.notes.filter {
                !workspace.noteIDs.contains($0.id)
            }.map { (id: $0.id, label: $0.title) })
        }, rows: {
            ForEach(items) { note in
                WorkspaceRow(
                    icon: "note.text",
                    title: note.title,
                    subtitle: nil,
                    onOpen: nil,
                    onUnpin: { workspaces.unpin(.note, itemID: note.id, from: workspace.id) }
                )
            }
        })
    }

    private func todosSection(_ workspace: Workspace) -> some View {
        let items = workspace.todoIDs.compactMap { id in
            todos.items.first(where: { $0.id == id })
        }
        return section(kind: .todo, count: items.count, addMenu: {
            addMenu(kind: .todo, workspace: workspace, candidates: todos.items.filter {
                !workspace.todoIDs.contains($0.id)
            }.map { (id: $0.id, label: $0.title) })
        }, rows: {
            ForEach(items) { todo in
                WorkspaceRow(
                    icon: todo.isCompleted ? "checkmark.circle.fill" : "circle",
                    title: todo.title,
                    subtitle: nil,
                    onOpen: { todos.toggleCompletion(id: todo.id) },
                    onUnpin: { workspaces.unpin(.todo, itemID: todo.id, from: workspace.id) }
                )
            }
        })
    }

    @ViewBuilder
    private func section<AddMenu: View, Rows: View>(
        kind: WorkspaceItemKind,
        count: Int,
        @ViewBuilder addMenu: () -> AddMenu,
        @ViewBuilder rows: () -> Rows
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(kind.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(count)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                addMenu()
            }
            .padding(.vertical, 4)
            rows()
        }
    }

    @ViewBuilder
    private func addMenu(
        kind: WorkspaceItemKind,
        workspace: Workspace,
        candidates: [(id: UUID, label: String)]
    ) -> some View {
        Menu {
            if candidates.isEmpty {
                Text("Nothing to pin")
            } else {
                ForEach(candidates.prefix(15), id: \.id) { candidate in
                    Button(candidate.label) {
                        workspaces.pin(kind, itemID: candidate.id, to: workspace.id)
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Pin an item to this workspace")
    }

    // MARK: - Actions

    private func createWorkspace() {
        let workspace = workspaces.createWorkspace()
        selectedWorkspaceID = workspace.id
        renameText = workspace.title
        isRenaming = true
    }

    private func beginRename() {
        renameText = selectedWorkspace?.title ?? ""
        isRenaming = true
    }

    private func commitRename() {
        if let id = selectedWorkspace?.id {
            workspaces.renameWorkspace(id: id, title: renameText)
        }
        isRenaming = false
    }

    private func deleteSelected() {
        guard let id = selectedWorkspace?.id else { return }
        workspaces.deleteWorkspace(id: id)
        selectedWorkspaceID = nil
        isRenaming = false
    }

    private func pruneMissingReferences() {
        workspaces.pruneMissingReferences(validIDs: [
            .clipboard: Set(clipboard.items.map(\.id) + clipboard.favorites.map(\.id)),
            .file: Set(files.stagedFiles.map(\.id)),
            .note: Set(notes.notes.map(\.id)),
            .todo: Set(todos.items.map(\.id))
        ])
    }
}

/// A single referenced item inside a workspace section.
private struct WorkspaceRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let onOpen: (() -> Void)?
    let onUnpin: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            if isHovered {
                Button(action: onUnpin) {
                    Image(systemName: "pin.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from workspace")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .contextMenu {
            Button("Remove from Workspace", action: onUnpin)
        }
    }
}
