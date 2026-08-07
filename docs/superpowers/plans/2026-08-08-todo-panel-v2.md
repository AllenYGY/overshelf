# Todo Panel V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the Todo panel draft card and task rows so priority, date, and keyboard-driven creation are faster without changing persistence or sorting.

**Architecture:** All changes are confined to `OverShelf/Views/TodoPanelView.swift`. `TodoDraftRow` and `TodoRow` become more self-contained; `TodoManager` is untouched.

**Tech Stack:** Swift 5, SwiftUI, AppKit.

---

## File Structure
- Modify: `OverShelf/Views/TodoPanelView.swift`
- Verify: `Tests/AppServicesTests/main.swift` (unchanged, regression suite)

### Task 1: Quick-Entry Draft Card

**Files:**
- Modify: `OverShelf/Views/TodoPanelView.swift`

- [ ] **Step 1: Replace the priority Menu and date popover in TodoDraftRow with inline controls**

Replace the `priorityControl` and `dueDateControl` computed properties with inline H/M/L buttons and date chips (Today / Tomorrow / +1 Week / Custom). Keep the existing `DueDateCalendarView` for Custom.

```swift
private var priorityControl: some View {
    HStack(spacing: 4) {
        ForEach(TodoItem.Priority.allCases) { p in
            Button {
                priority = p
            } label: {
                HStack(spacing: 3) {
                    Circle()
                        .fill(p.swiftUIColor)
                        .frame(width: 6, height: 6)
                    Text(p.displayName.prefix(1))
                        .font(.system(size: 9, weight: .medium))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(priority == p ? Theme.rowHover : Color.clear)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
}

private var dueDateControl: some View {
    HStack(spacing: 4) {
        dateChip("Today", date: Date())
        dateChip("Tomorrow", date: Date().addingTimeInterval(86400))
        dateChip("+1 Week", date: Date().addingTimeInterval(7 * 86400))
        Button { showDatePicker.toggle() } label: {
            Text("Custom")
                .font(.system(size: 9))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isCustomDate ? Theme.rowHover : Color.clear)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDatePicker, arrowEdge: .top) {
            DueDateCalendarView(
                selected: dueDate,
                onSelect: { date in dueDate = date; showDatePicker = false },
                onClear: { dueDate = nil; showDatePicker = false }
            )
        }
    }
}

private func dateChip(_ label: String, date: Date) -> some View {
    Button { dueDate = date } label: {
        Text(label)
            .font(.system(size: 9))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isSameDay(dueDate, date) ? Theme.rowHover : Color.clear)
            .cornerRadius(4)
    }
    .buttonStyle(.plain)
}
```

Add helpers:

```swift
private var isCustomDate: Bool {
    guard let d = dueDate else { return false }
    return !isSameDay(d, Date()) && !isSameDay(d, Date().addingTimeInterval(86400)) && !isSameDay(d, Date().addingTimeInterval(7 * 86400))
}

private func isSameDay(_ a: Date?, _ b: Date) -> Bool {
    guard let a = a else { return false }
    return Calendar.current.isDate(a, inSameDayAs: b)
}
```

- [ ] **Step 2: Add Add & New action and keyboard shortcuts**

Add a second submit button in the draft card that calls `onSubmit(addAnother: true)`. Change the draft action signatures to `onSubmit: (Bool) -> Void`. In `TodoPanelView.submitDraft(addAnother:)`, if `addAnother` is true, create the todo, reset `draft` to a fresh `TodoDraft()`, and increment `draftFocusRequest`. Use `.keyboardShortcut(.return, modifiers: .command)` on the Add & New button.

- [ ] **Step 3: Build**

Run: `./script/build_and_run.sh build`
Expected: no Swift errors.

- [ ] **Step 4: Commit**

```bash
git add OverShelf/Views/TodoPanelView.swift
git commit -m "Make the Todo draft card keyboard-first" \
  -m "Constraint: Keep draft state transient and the existing sort order.\nConfidence: high\nScope-risk: narrow\nTested: ./script/build_and_run.sh build\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 2: Simplify Task Row and Filter Bar

**Files:**
- Modify: `OverShelf/Views/TodoPanelView.swift`

- [ ] **Step 1: Remove the pencil hover action and add relative date formatting**

In `TodoRow`, delete the pencil button. Add a `relativeDueDate` computed property that returns "Today", "Tomorrow", "In N days", "Yesterday", "Overdue by N days", or the short date. Color overdue dates red.

```swift
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
```

Use `relativeDueDate` in the metadata line and apply `foregroundStyle(isOverdue ? .red : .secondary)`.

- [ ] **Step 2: Show counts in the filter bar**

Compute `allCount`, `activeCount`, and `completedCount` in `TodoPanelView` and render them as `All (n)` / `Active (n)` / `Done (n)` with the count in secondary style.

- [ ] **Step 3: Add empty-state quick action**

When `displayedItems.isEmpty && draft == nil`, show a button "Add first task" that calls `beginDraft()`.

- [ ] **Step 4: Run tests**

Run: `./script/build_and_run.sh test`
Expected: all suites pass.

- [ ] **Step 5: Commit**

```bash
git add OverShelf/Views/TodoPanelView.swift
git commit -m "Make Todo rows scannable and the empty state actionable" \
  -m "Constraint: Keep row actions to calendar and trash on hover.\nConfidence: high\nScope-risk: narrow\nTested: ./script/build_and_run.sh test\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 3: Final Verification

- [ ] **Step 1:** `./script/build_and_run.sh test`
- [ ] **Step 2:** `./script/build_and_run.sh verify`
- [ ] **Step 3:** `git diff --check`
- [ ] **Step 4:** `plutil -lint OverShelf/Info.plist`
- [ ] **Step 5:** Launch the app and verify keyboard flow, continuous add, filter counts, relative dates, and light/dark mode.
