import SwiftUI

/// The todo list panel: create, edit, complete, and filter tasks.
struct TodoPanelView: View {
    @Environment(TodoManager.self) private var todos
    @Environment(UIState.self) private var uiState

    @State private var searchText = ""
    @State private var newTodoTitle = ""
    @State private var filter: TodoFilter = .all

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
                iconName: "checklist",
                onDetach: uiState.detachedPanels.contains(.todo) ? nil : { detachTodo() },
                onReattach: uiState.detachedPanels.contains(.todo) ? { reattachTodo() } : nil
            )

            VStack(spacing: 0) {
                // Search + add
                HStack(spacing: 6) {
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
                    .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.4))
                    .cornerRadius(6)

                    HStack(spacing: 4) {
                        TextField("New task", text: $newTodoTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .onSubmit { addTodo() }
                        Button { addTodo() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .unemphasizedSelectedContentBackgroundColor).opacity(0.4))
                    .cornerRadius(6)
                }
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
                if displayedItems.isEmpty {
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

    private func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        todos.createTodo(title: title)
        newTodoTitle = ""
    }

    private func detachTodo() {
        NotificationCenter.default.post(name: .detachPanel, object: nil, userInfo: ["panel": PanelType.todo])
    }

    private func reattachTodo() {
        uiState.onReattachPanel?(.todo)
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
                        VStack(spacing: 8) {
                            DatePicker(
                                "Due",
                                selection: Binding(
                                    get: { item.dueDate ?? Date() },
                                    set: { onUpdateDueDate($0) }
                                ),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            if item.dueDate != nil {
                                Button("Clear due date") {
                                    onUpdateDueDate(nil)
                                    showDatePicker = false
                                }
                                .font(.system(size: 11))
                            }
                        }
                        .padding(10)
                        .frame(width: 240)
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
