import SwiftUI

extension TodoItem.Priority {
    var swiftUIColor: Color {
        switch self {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}

/// The todo list panel: create, edit, complete, and filter tasks.
struct TodoPanelView: View {
    @Environment(TodoManager.self) private var todos

    @State private var searchText = ""
    @State private var filter: TodoFilter = .all
    @State private var draft: TodoDraft?
    @State private var draftFocusRequest = 0

    private struct TodoDraft: Equatable {
        var title = ""
        var priority: TodoItem.Priority = .medium
        var dueDate: Date?
    }

    var displayedItems: [TodoItem] {
        let base = searchText.isEmpty ? todos.items : todos.search(searchText)
        switch filter {
        case .all: return base
        case .active: return base.filter { !$0.isCompleted }
        case .completed: return base.filter { $0.isCompleted }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(
                title: "Todo",
                iconName: "checklist"
            ) {
                Button(action: beginDraft) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Add task")
            }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("Search todos", text: $searchText)
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
                .padding(8)

                // Filter bar
                HStack(spacing: 0) {
                    ForEach(TodoFilter.allCases) { f in
                        Button {
                            filter = f
                        } label: {
                            Text(f.displayName)
                                .font(.system(size: 11))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .foregroundStyle(filter == f ? Color.white : .primary)
                                .background(filter == f ? Color.accentColor : Color.clear)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        if f != TodoFilter.allCases.last {
                            Divider()
                                .frame(height: 12)
                                .padding(.horizontal, 4)
                        }
                    }

                    Spacer()

                    Text("\(todos.incompleteCount) left")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                // Todo list
                if draft == nil && displayedItems.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text(searchText.isEmpty ? "No tasks yet" : "No matches")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if let currentDraft = draft {
                                TodoDraftRow(
                                    title: Binding(
                                        get: { currentDraft.title },
                                        set: { draft?.title = $0 }
                                    ),
                                    priority: Binding(
                                        get: { currentDraft.priority },
                                        set: { draft?.priority = $0 }
                                    ),
                                    dueDate: Binding(
                                        get: { currentDraft.dueDate },
                                        set: { draft?.dueDate = $0 }
                                    ),
                                    focusRequest: draftFocusRequest,
                                    onSubmit: submitDraft,
                                    onCancel: { draft = nil }
                                )
                                Divider()
                            }
                            ForEach(displayedItems) { item in
                                TodoRow(
                                    item: item,
                                    onToggle: { todos.toggleCompletion(id: item.id) },
                                    onUpdateTitle: { todos.updateTitle(id: item.id, title: $0) },
                                    onUpdatePriority: { todos.updatePriority(id: item.id, priority: $0) },
                                    onUpdateDueDate: { todos.updateDueDate(id: item.id, dueDate: $0) },
                                    onDelete: { todos.deleteTodo(id: item.id) }
                                )
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.panelBg)
    }

    private func beginDraft() {
        if draft == nil {
            draft = TodoDraft()
        }
        draftFocusRequest += 1
    }

    private func submitDraft() {
        guard let currentDraft = draft else { return }
        let title = currentDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        todos.createTodo(
            title: title,
            priority: currentDraft.priority,
            dueDate: currentDraft.dueDate
        )
        draft = nil
    }
}

/// An inline draft row for collecting task title, priority, and due date.
struct TodoDraftRow: View {
    @Binding var title: String
    @Binding var priority: TodoItem.Priority
    @Binding var dueDate: Date?
    let focusRequest: Int
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isTitleFocused: Bool
    @State private var showDatePicker = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                TextField("New task", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($isTitleFocused)
                    .onSubmit(onSubmit)
                    .onExitCommand(perform: onCancel)

                HStack(spacing: 6) {
                    priorityControl
                    dueDateControl
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button(action: onSubmit) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10))
                        .foregroundStyle(canSubmit ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .help("Add task")

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .onAppear { isTitleFocused = true }
        .onChange(of: focusRequest) { _, _ in isTitleFocused = true }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var priorityControl: some View {
        Menu {
            ForEach(TodoItem.Priority.allCases) { p in
                Button(p.displayName) { priority = p }
            }
        } label: {
            HStack(spacing: 2) {
                Circle()
                    .fill(priority.swiftUIColor)
                    .frame(width: 6, height: 6)
                Text(priority.displayName)
                    .font(.system(size: 9))
            }
        }
        .menuStyle(.borderlessButton)
        .frame(height: 14)
    }

    private var dueDateControl: some View {
        Button { showDatePicker.toggle() } label: {
            HStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 9))
                if let date = dueDate {
                    Text(date, style: .date)
                        .font(.system(size: 9))
                } else {
                    Text("No date")
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(dueDate == nil ? .secondary : Color.accentColor)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .top) {
            DueDateCalendarView(
                selected: dueDate,
                onSelect: { date in
                    dueDate = date
                    showDatePicker = false
                },
                onClear: {
                    dueDate = nil
                    showDatePicker = false
                }
            )
        }
    }
}


enum TodoFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .active: return "Active"
        case .completed: return "Done"
        }
    }
}

/// A single todo row with inline editing and priority/date controls.
struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onUpdateTitle: (String) -> Void
    let onUpdatePriority: (TodoItem.Priority) -> Void
    let onUpdateDueDate: (Date?) -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showDatePicker = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isCompleted ? Color.green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Task", text: $editText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            onUpdateTitle(editText)
                            isEditing = false
                        }
                        .onChange(of: isTextFieldFocused) { _, focused in
                            if !focused && isEditing {
                                onUpdateTitle(editText)
                                isEditing = false
                            }
                        }
                        .onExitCommand {
                            editText = item.title
                            isEditing = false
                        }
                } else {
                    Text(item.title)
                        .font(.system(size: 12))
                        .lineLimit(2)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .onTapGesture(count: 2) {
                            editText = item.title
                            isEditing = true
                            isTextFieldFocused = true
                        }
                }

                HStack(spacing: 6) {
                    Menu {
                        ForEach(TodoItem.Priority.allCases) { priority in
                            Button(priority.displayName) {
                                onUpdatePriority(priority)
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(priorityColor(item.priority))
                                .frame(width: 6, height: 6)
                            Text(item.priority.rawValue.capitalized)
                                .font(.system(size: 9))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: 14)

                    if let due = item.dueDate {
                        Text(due, style: .date)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered || isEditing || showDatePicker {
                HStack(spacing: 6) {
                    Button {
                        editText = item.title
                        isEditing = true
                        isTextFieldFocused = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Rename task")

                    Button {
                        showDatePicker.toggle()
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(item.dueDate == nil ? .secondary : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Set due date")
                    .popover(isPresented: $showDatePicker, arrowEdge: .top) {
                        DueDateCalendarView(
                            selected: item.dueDate,
                            onSelect: { date in
                                onUpdateDueDate(date)
                                showDatePicker = false
                            },
                            onClear: {
                                onUpdateDueDate(nil)
                                showDatePicker = false
                            }
                        )
                    }

                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Theme.rowHover : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .contextMenu {
            Button(item.isCompleted ? "Mark incomplete" : "Mark complete") { onToggle() }
            Divider()
            Button("Rename") {
                editText = item.title
                isEditing = true
                isTextFieldFocused = true
            }
            Divider()
            Menu("Priority") {
                ForEach(TodoItem.Priority.allCases) { priority in
                    Button(priority.displayName) { onUpdatePriority(priority) }
                }
            }
            Button("Set due date") { onUpdateDueDate(Date()) }
            Button("Clear due date") { onUpdateDueDate(nil) }
            Divider()
            Button("Delete") { onDelete() }
                .foregroundStyle(.red)
        }
    }

    private func priorityColor(_ priority: TodoItem.Priority) -> Color {
        switch priority {
        case .low: return .gray
        case .medium: return .orange
        case .high: return .red
        }
    }
}
