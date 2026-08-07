import SwiftUI

/// The quick notes panel: create, edit, search, pin, and delete notes.
struct NotesPanelView: View {
    @Environment(NotesManager.self) private var notes
    @Environment(UIState.self) private var uiState

    @State private var searchText = ""
    @State private var selectedNoteId: UUID?
    @State private var noteBody: String = ""
    @State private var searchFocused = false
    @State private var isPreviewing = false
    @State private var didConfigureDemoScene = false

    var displayedNotes: [Note] {
        notes.search(searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Notes",
                iconName: "note.text"
            )

            if let id = selectedNoteId, let note = notes.notes.first(where: { $0.id == id }) {
                noteEditor(note)
            } else {
                noteList
            }
        }
        .background(Theme.panelBg)
        .onAppear(perform: configureDemoSceneIfNeeded)
    }

    // MARK: - Note list

    private var noteList: some View {
        VStack(spacing: 0) {
            // Search + new
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("Search notes", text: $searchText)
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
                .padding(.vertical, 5)
                .background(Theme.fieldBg)
                .cornerRadius(6)

                Button {
                    let note = notes.createNote()
                    selectedNoteId = note.id
                    noteBody = ""
                    isPreviewing = false
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("New note")
            }
            .padding(8)

            // Notes list
            if displayedNotes.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No notes yet" : "No matches")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedNotes) { note in
                            NoteRow(
                                note: note,
                                onTap: {
                                    selectedNoteId = note.id
                                    noteBody = note.body
                                    isPreviewing = false
                                },
                                onPin: { notes.togglePin(id: note.id) },
                                onDelete: {
                                    if selectedNoteId == note.id {
                                        selectedNoteId = nil
                                    }
                                    notes.deleteNote(id: note.id)
                                }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Note editor

    private func configureDemoSceneIfNeeded() {
        guard !didConfigureDemoScene else { return }
        didConfigureDemoScene = true
        guard ReadmeDemoPresentation.startsNotesPreview(scene: uiState.readmeDemoScene),
              let note = notes.notes.first else { return }
        selectedNoteId = note.id
        noteBody = note.body
        isPreviewing = true
    }

    private func noteEditor(_ note: Note) -> some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack(spacing: 6) {
            Button {
                notes.updateNote(id: note.id, body: noteBody)
                selectedNoteId = nil
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                Text("Notes")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 2) {
                modeButton(title: "Edit", isActive: !isPreviewing) {
                    isPreviewing = false
                }
                modeButton(title: "Preview", isActive: isPreviewing) {
                    isPreviewing = true
                }
            }
            .padding(2)
            .background(Theme.fieldBg)
            .cornerRadius(6)

            Button { notes.togglePin(id: note.id) } label: {
                Image(systemName: note.pinned ? "pin.fill" : "pin")
                    .font(.system(size: 11))
                        .foregroundStyle(note.pinned ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(note.pinned ? "Unpin" : "Pin")

                Button {
                    notes.deleteNote(id: note.id)
                    selectedNoteId = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.sidebarBg)

            // Editor
            if isPreviewing {
                MarkdownPreviewView(markdown: noteBody)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $noteBody)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .onChange(of: noteBody) { _, newBody in
                        notes.updateNote(id: note.id, body: newBody)
                    }
            }
        }
    }

    @ViewBuilder
    private func modeButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.white : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

}

/// A single note row in the list.
struct NoteRow: View {
    let note: Note
    let onTap: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            if note.pinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 12, weight: note.pinned ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(note.modifiedAt, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(note.pinned ? "Unpin" : "Pin") { onPin() }
            Divider()
            Button("Delete") { onDelete() }
                .foregroundStyle(.red)
        }
    }
}
