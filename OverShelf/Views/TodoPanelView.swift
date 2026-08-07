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
    @State private var editingTodoId: UUID?

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
                Button(action: createAndEdit) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Add task")
            }

            if let id = editingTodoId, let todo = todos.items.first(where: { $0.id == id }) {
                todoEditor(todo)
            } else {
                todoList
            }
        }
        .background(Theme.panelBg)
    }

    // MARK: - Todo list

    private var todoList: some View {
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
                            HStack(spacing: 2) {
                                Text(f.displayName)
                                Text("(\(count(for: f)))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(filter == f ? Color.white.opacity(0.8) : Color.secondary)
                            }
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
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text(searchText.isEmpty ? "No tasks yet" : "No matches")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                        if searchText.isEmpty {
                            Button("Add first task") { createAndEdit() }
                                .font(.system(size: 11))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                        }
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

    private func count(for filter: TodoFilter) -> Int {
        switch filter {
        case .all: return todos.items.count
        case .active: return todos.items.filter { !$0.isCompleted }.count
        case .completed: return todos.items.filter { $0.isCompleted }.count
        }
    }

    private func createAndEdit() {
        let todo = todos.createTodo(title: "")
        editingTodoId = todo.id
    }

    private func finishEditing(_ todo: TodoItem) {
        if todo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            todos.deleteTodo(id: todo.id)
        }
        editingTodoId = nil
    }

    // MARK: - Todo editor

    private func todoEditor(_ todo: TodoItem) -> some View {
        VStack(spacing: 0) {
            // Editor toolbar
            HStack(spacing: 6) {
                Button {
                    finishEditing(todo)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12))
                    Text("Todo")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    todos.deleteTodo(id: todo.id)
                    editingTodoId = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete task")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.sidebarBg)

            VStack(alignment: .leading, spacing: 12) {
                TextField("Task title", text: Binding(
                    get: { todo.title },
                    set: { todos.updateTitle(id: todo.id, title: $0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.fieldBg)
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        ForEach(TodoItem.Priority.allCases) { p in
                            Button {
                                todos.updatePriority(id: todo.id, priority: p)
                            } label: {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(p.swiftUIColor)
                                        .frame(width: 8, height: 8)
                                    Text(p.displayName)
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(todo.priority == p ? Theme.rowHover : Color.clear)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Due date")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        dateButton("Today", date: Date(), todo: todo)
                        dateButton("Tomorrow", date: Date().addingTimeInterval(86400), todo: todo)
                        dateButton("+1 Week", date: Date().addingTimeInterval(7 * 86400), todo: todo)
                        TodoDatePickerButton(todo: todo, todos: todos)
                    }
                }

                Spacer()
            }
            .padding(10)
        }
    }

    private func dateButton(_ label: String, date: Date, todo: TodoItem) -> some View {
        Button {
            todos.updateDueDate(id: todo.id, dueDate: date)
        } label: {
            Text(label)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSameDay(todo.dueDate, date) ? Theme.rowHover : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func isSameDay(_ a: Date?, _ b: Date) -> Bool {
        guard let a = a else { return false }
        return Calendar.current.isDate(a, inSameDayAs: b)
    }
}

/// A calendar button used inside the Todo editor.
struct TodoDatePickerButton: View {
    let todo: TodoItem
    let todos: TodoManager

    @State private var showDatePicker = false

    var body: some View {
        Button { showDatePicker.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                if let due = todo.dueDate {
                    Text(due, style: .date)
                        .font(.system(size: 11))
                } else {
                    Text("Custom")
                        .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(todo.dueDate == nil ? .secondary : Color.accentColor)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .top) {
            DueDateCalendarView(
                selected: todo.dueDate,
                onSelect: { date in
                    todos.updateDueDate(id: todo.id, dueDate: date)
                    showDatePicker = false
                },
                onClear: {
                    todos.updateDueDate(id: todo.id, dueDate: nil)
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
                                .fill(item.priority.swiftUIColor)
                                .frame(width: 6, height: 6)
                            Text(item.priority.rawValue.capitalized)
                                .font(.system(size: 9))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: 14)

                    if let label = relativeDueDate {
                        Text(label)
                            .font(.system(size: 9))
                            .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered || isEditing || showDatePicker {
                HStack(spacing: 6) {
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

    private var relativeDueDate: String? {
        guard let due = item.dueDate else { return nil }
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "Today" }
        if cal.isDateInTomorrow(due) { return "Tomorrow" }
        if cal.isDateInYesterday(due) { return "Yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: due)).day ?? 0
        if days > 0 { return "In \(days) days" }
        return "Overdue by \(-days) days"
    }

    private var isOverdue: Bool {
        guard let due = item.dueDate else { return false }
        return due < Date() && !item.isCompleted
    }
}
