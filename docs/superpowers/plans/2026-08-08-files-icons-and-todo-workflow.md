# Files Icons and Todo Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted List / Icons mode to Files and replace Todo's permanent creation field with an inline metadata-aware draft backed by deterministic priority and due-date sorting.

**Architecture:** Persist the Files preference as an optional Codable setting with a List fallback and migration. Keep file-grid presentation state inside `FilesPanelView`, while `FileGridLayout` owns the testable width-to-column rule. Keep unsubmitted Todo draft state in `TodoPanelView`; extend `TodoManager` so atomic creation and every order-affecting mutation pass through one total-order comparator.

**Tech Stack:** Swift 5, SwiftUI, AppKit (`NSWorkspace`), Observation, JSON persistence, repository shell-based Swift test harness.

---

## File Structure

- Modify `OverShelf/Models/AppSettings.swift`: define the persisted Files view mode, expose it through `AppSettings`, and migrate missing values to List.
- Modify `Tests/MigrationTests/main.swift`: prove legacy settings retain unrelated values and gain List mode; prove Icons persists.
- Modify `OverShelf/Views/Shared/Theme.swift`: let `PanelHeader` accept an optional trailing SwiftUI control without changing existing call sites.
- Modify `OverShelf/Views/FilesPanelView.swift`: add the segmented mode picker, adaptive grid layout, and icon tiles while reusing existing file actions.
- Create `OverShelf/Models/FileGridLayout.swift`: hold the deterministic 2/3-column layout calculation used by the grid and tests.
- Create `Tests/FileGridLayoutTests/main.swift`: verify narrow and normal panel widths.
- Modify `script/build_and_run.sh`: compile and run the new layout test.
- Modify `OverShelf/Services/TodoManager.swift`: accept metadata at creation and centralize the complete deterministic ordering rule.
- Modify `Tests/AppServicesTests/main.swift`: lock atomic creation and sorting after load and mutations.
- Modify `OverShelf/Views/TodoPanelView.swift`: introduce the inline draft, keyboard behavior, reusable priority badge, and header add button.

### Task 1: Persist the Files View Preference Safely

**Files:**
- Modify: `OverShelf/Models/AppSettings.swift`
- Test: `Tests/MigrationTests/main.swift`

- [ ] **Step 1: Write the failing legacy migration and round-trip assertions**

Add assertions after `let settings = AppSettings(...)` and after the new-settings assertions:

```swift
guard settings.filesViewMode == .list else {
    fatalError("legacy settings should migrate Files to List view")
}

settings.filesViewMode = .icons
guard AppSettings(persistence: persistence).filesViewMode == .icons else {
    fatalError("Files view mode should persist across reload")
}

guard newSettings.filesViewMode == .list else {
    fatalError("new settings should default Files to List view")
}
```

Extend the migrated JSON check with:

```swift
obj["filesViewMode"] as? String == "list"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./script/build_and_run.sh test`

Expected: compilation fails because `filesViewMode` and `FilesViewMode` do not exist.

- [ ] **Step 3: Add the optional persisted field, wrapper, and migration**

In `OverShelf/Models/AppSettings.swift`, add:

```swift
enum FilesViewMode: String, Codable, CaseIterable, Identifiable {
    case list
    case icons

    var id: String { rawValue }
}
```

Add this optional field to `AppSettingsData`:

```swift
var filesViewMode: FilesViewMode? = .list
```

Expose a non-optional wrapper on `AppSettings`:

```swift
var filesViewMode: FilesViewMode {
    get { data.filesViewMode ?? .list }
    set { data.filesViewMode = newValue; save() }
}
```

At the beginning of `migrateIfNeeded()`, add:

```swift
if data.filesViewMode == nil {
    data.filesViewMode = .list
    changed = true
}
```

- [ ] **Step 4: Run migration tests and confirm the legacy opacity assertion still passes**

Run: `./script/build_and_run.sh test`

Expected: all existing suites pass, including `Migration test passed`, and legacy `windowOpacity == 0.73` remains intact.

- [ ] **Step 5: Commit the settings slice**

```bash
git add OverShelf/Models/AppSettings.swift Tests/MigrationTests/main.swift
git commit -m "Remember the Files presentation without risking legacy settings" \
  -m "Constraint: Missing Codable fields must not reset unrelated settings.\nConfidence: high\nScope-risk: narrow\nTested: ./script/build_and_run.sh test\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 2: Add a Testable Adaptive Files Grid Rule

**Files:**
- Create: `OverShelf/Models/FileGridLayout.swift`
- Create: `Tests/FileGridLayoutTests/main.swift`
- Modify: `script/build_and_run.sh`

- [ ] **Step 1: Write the failing layout executable**

Create `Tests/FileGridLayoutTests/main.swift`:

```swift
import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

require(FileGridLayout.columnCount(for: 180) == 2, "narrow Files panels should use two columns")
require(FileGridLayout.columnCount(for: 240) == 3, "normal Files panels should use three columns")
require(FileGridLayout.columnCount(for: 900) == 3, "Files grids should stay capped at three columns")

print("File grid layout test passed")
```

Add a `FileGridLayoutTests` compile-and-run block to the `test)` branch of `script/build_and_run.sh` using `-framework CoreGraphics`, `OverShelf/Models/FileGridLayout.swift`, and the new test file.

- [ ] **Step 2: Run the test suite to verify the new executable fails to compile**

Run: `./script/build_and_run.sh test`

Expected: `FileGridLayoutTests` fails because `FileGridLayout` does not exist.

- [ ] **Step 3: Implement the bounded column calculation**

Create `OverShelf/Models/FileGridLayout.swift`:

```swift
import CoreGraphics

enum FileGridLayout {
    static let horizontalPadding: CGFloat = 16
    static let spacing: CGFloat = 8
    static let minimumTileWidth: CGFloat = 68

    static func columnCount(for panelWidth: CGFloat) -> Int {
        let contentWidth = max(0, panelWidth - horizontalPadding)
        let possible = Int((contentWidth + spacing) / (minimumTileWidth + spacing))
        return min(3, max(2, possible))
    }
}
```

- [ ] **Step 4: Run the test suite**

Run: `./script/build_and_run.sh test`

Expected: output contains `File grid layout test passed` and all other suites pass.

- [ ] **Step 5: Commit the layout slice**

```bash
git add OverShelf/Models/FileGridLayout.swift Tests/FileGridLayoutTests/main.swift script/build_and_run.sh
git commit -m "Keep icon density stable as the Files panel narrows" \
  -m "Constraint: The grid must adapt between two and three columns without a user density setting.\nConfidence: high\nScope-risk: narrow\nTested: ./script/build_and_run.sh test\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 3: Build the Files List / Icons Interface

**Files:**
- Modify: `OverShelf/Views/Shared/Theme.swift`
- Modify: `OverShelf/Views/FilesPanelView.swift`

- [ ] **Step 1: Extend `PanelHeader` with a type-safe trailing slot**

Replace `PanelHeader` with a generic form while preserving the two-argument initializer:

```swift
struct PanelHeader<Trailing: View>: View {
    let title: String
    let iconName: String
    @ViewBuilder let trailing: Trailing

    init(title: String, iconName: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.iconName = iconName
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 10)
        .frame(height: Theme.headerHeight)
        .background(Theme.sidebarBg)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(title: String, iconName: String) {
        self.init(title: title, iconName: iconName) { EmptyView() }
    }
}
```

- [ ] **Step 2: Bind Files view mode to settings and add the segmented header control**

In `FilesPanelView`, add `@Environment(AppSettings.self) private var settings`. Pass a trailing picker to `PanelHeader`:

```swift
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
```

- [ ] **Step 3: Split the existing list into a dedicated view builder and add the adaptive grid**

Keep the current `LazyVStack` behavior in `fileList`. Add a `GeometryReader`-backed `fileGrid` that creates `FileGridLayout.columnCount(for:)` flexible columns and renders `FileIconTile` in a `LazyVGrid`. Use 8-point grid spacing and 8-point horizontal padding. Both modes must use the same `hoveredFile`, `revealFile`, `files.remove`, panel-level `.onDrop`, footer, and staged-file order.

```swift
@ViewBuilder
private var fileCollection: some View {
    switch settings.filesViewMode {
    case .list: fileList
    case .icons: fileGrid
    }
}
```

- [ ] **Step 4: Add the fixed-height icon tile**

Add `FileIconTile` beside `FileRow`. It must render a 44-by-44 native icon or `doc` fallback, a two-line centered filename using `.truncationMode(.middle)`, and an overlaid hover-only Finder button so the 86-point tile height never changes. Apply `.contentShape(Rectangle())`, the same context menu actions, and the same URL `NSItemProvider` drag source used by list rows.

```swift
.contextMenu {
    Button("Show in Finder", action: onReveal)
    Divider()
    Button("Remove", action: onRemove).foregroundStyle(.red)
}
.onDrag {
    guard let url = file.url else { return NSItemProvider() }
    return NSItemProvider(object: url as NSURL)
}
```

- [ ] **Step 5: Build the app**

Run: `./script/build_and_run.sh build`

Expected: `Built and staged .../dist/OverShelf.app` with no Swift errors.

- [ ] **Step 6: Commit the Files UI slice**

```bash
git add OverShelf/Views/Shared/Theme.swift OverShelf/Views/FilesPanelView.swift
git commit -m "Let staged files stay scannable at either density" \
  -m "Constraint: Drag, reveal, remove, drop, count, and Clear behavior must remain identical in both views.\nConfidence: high\nScope-risk: moderate\nTested: ./script/build_and_run.sh build\nNot-tested: Manual drag interaction remains for final visual QA.\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 4: Lock Atomic Todo Creation and Total Ordering

**Files:**
- Modify: `Tests/AppServicesTests/main.swift`
- Modify: `OverShelf/Services/TodoManager.swift`

- [ ] **Step 1: Add failing creation metadata assertions**

Create a separate Todo test directory and manager so existing lifecycle checks stay isolated:

```swift
let todoSortDir = tempDir.appendingPathComponent("todo-sorting")
try? FileManager.default.createDirectory(at: todoSortDir, withIntermediateDirectories: true)
let sortedTodos = TodoManager(persistence: PersistenceManager(baseURL: todoSortDir))
let dueSoon = Date(timeIntervalSince1970: 2_000)
let created = sortedTodos.createTodo(title: "Urgent", priority: .high, dueDate: dueSoon)
guard created.title == "Urgent", created.priority == .high, created.dueDate == dueSoon else {
    fail("Todo creation should apply title, priority, and due date atomically")
}
```

- [ ] **Step 2: Add failing order assertions covering all primary keys**

Create active High dated/undated, Medium dated, Low dated, and completed High tasks. Assert the IDs are ordered as: incomplete High dated by ascending date, incomplete High undated, incomplete Medium, incomplete Low, completed High. Flush, reload, and assert the same ID sequence survives disk loading.

- [ ] **Step 3: Add failing mutation assertions**

Update a Low task to High, give it the earliest date, and assert it moves to the front. Toggle it completed and assert it moves behind every incomplete item. Clear a due date and assert it moves behind dated peers of the same priority.

- [ ] **Step 4: Run tests to verify the new creation call fails**

Run: `./script/build_and_run.sh test`

Expected: compilation fails because `createTodo` does not accept `priority` and `dueDate`.

- [ ] **Step 5: Implement atomic creation and the total comparator**

Change creation to:

```swift
@discardableResult
func createTodo(
    title: String = "",
    priority: TodoItem.Priority = .medium,
    dueDate: Date? = nil
) -> TodoItem {
    let todo = TodoItem(title: title, priority: priority, dueDate: dueDate)
    items.append(todo)
    sortItems()
    scheduleSave()
    return todo
}
```

Replace `sortItems()` with a comparator that checks, in order: completion, `priority.sortOrder`, presence of a due date, earlier due date, newer `modifiedAt`, newer `createdAt`, then `id.uuidString` ascending. Keep `sortItems()` calls after load, creation, completion, priority, and due-date mutations.

```swift
if let leftDue = a.dueDate, let rightDue = b.dueDate, leftDue != rightDue {
    return leftDue < rightDue
}
if a.dueDate == nil, b.dueDate != nil { return false }
if a.dueDate != nil, b.dueDate == nil { return true }
if a.modifiedAt != b.modifiedAt { return a.modifiedAt > b.modifiedAt }
if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
return a.id.uuidString < b.id.uuidString
```

- [ ] **Step 6: Run the complete service suite**

Run: `./script/build_and_run.sh test`

Expected: `App services test passed`, the reload sequence matches, and all other suites pass.

- [ ] **Step 7: Commit the Todo model slice**

```bash
git add OverShelf/Services/TodoManager.swift Tests/AppServicesTests/main.swift
git commit -m "Make task urgency and time determine a stable reading order" \
  -m "Constraint: Completion grouping precedes priority, and undated tasks follow dated peers.\nRejected: Modification-time-only ties | They make due-date order unstable.\nConfidence: high\nScope-risk: moderate\nDirective: Every future order-affecting mutation must call sortItems before persistence.\nTested: ./script/build_and_run.sh test\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 5: Replace the Permanent Todo Field with an Inline Draft

**Files:**
- Modify: `OverShelf/Views/TodoPanelView.swift`

- [ ] **Step 1: Add view-owned draft state and the header add action**

Replace `newTodoTitle` with one optional draft state:

```swift
private struct TodoDraft: Equatable {
    var title = ""
    var priority: TodoItem.Priority = .medium
    var dueDate: Date?
}

@State private var draft: TodoDraft?
@State private var draftFocusRequest = 0
```

Add a trailing `+` button to `PanelHeader`. Its action creates the default draft only when nil, then increments `draftFocusRequest` so repeated clicks refocus the existing title field.

- [ ] **Step 2: Make Search full width and place the draft before persisted rows**

Remove the permanent `New task` field. Keep the existing search field and padding across the available width. In the scrolling content, render `TodoDraftRow` before `ForEach(displayedItems)` whenever `draft != nil`, including when filters or search yield no persisted results. Only show the empty state when both the draft is nil and `displayedItems.isEmpty`.

- [ ] **Step 3: Implement `TodoDraftRow` controls and keyboard behavior**

Create a focused component accepting bindings for title, priority, and due date plus `focusRequest`, `onSubmit`, and `onCancel`. Use `@FocusState`, `.onSubmit`, and `.onExitCommand`. Reuse `DueDateCalendarView` for the optional date. Add visible icon buttons with tooltips for Add and Cancel. Disable Add for a whitespace-only title.

```swift
.onSubmit(onSubmit)
.onExitCommand(perform: onCancel)
.onAppear { isTitleFocused = true }
.onChange(of: focusRequest) { _, _ in isTitleFocused = true }
```

Submission trims the title and calls:

```swift
todos.createTodo(
    title: title,
    priority: currentDraft.priority,
    dueDate: currentDraft.dueDate
)
draft = nil
```

An empty Enter does nothing; Cancel sets `draft = nil`. No draft state enters `TodoManager` before valid submission.

- [ ] **Step 4: Centralize accessible priority styling**

Move the existing red/orange/gray mapping to a reusable `TodoPriorityBadge` or `TodoItem.Priority` SwiftUI helper in `TodoPanelView.swift`. Render both the colored dot and `displayName` in `TodoRow` and `TodoDraftRow`. Use red for High, orange for Medium, and gray for Low; completed rows may reduce opacity but must retain the label.

- [ ] **Step 5: Build and run automated tests**

Run: `./script/build_and_run.sh test`

Expected: all test executables pass and the app launch check succeeds.

- [ ] **Step 6: Commit the Todo UI slice**

```bash
git add OverShelf/Views/TodoPanelView.swift
git commit -m "Let tasks become complete ideas before they enter the list" \
  -m "Constraint: Draft title, priority, and date remain transient until Add or valid Enter.\nRejected: A permanent creation field | It cannot collect metadata cleanly in the compact panel.\nConfidence: high\nScope-risk: moderate\nTested: ./script/build_and_run.sh test\nNot-tested: Keyboard focus and popover placement remain for final manual QA.\nCo-authored-by: OmX <omx@oh-my-codex.dev>"
```

### Task 6: Final Build, Visual QA, and Regression Check

**Files:**
- Verify: `OverShelf/Views/FilesPanelView.swift`
- Verify: `OverShelf/Views/TodoPanelView.swift`
- Verify: `OverShelf/Models/AppSettings.swift`
- Verify: `OverShelf/Services/TodoManager.swift`

- [ ] **Step 1: Run formatting and metadata checks**

Run:

```bash
git diff --check
plutil -lint OverShelf/Info.plist
```

Expected: no diff errors and `OverShelf/Info.plist: OK`.

- [ ] **Step 2: Run all automated tests and launch verification**

Run:

```bash
./script/build_and_run.sh test
./script/build_and_run.sh verify
```

Expected: every test executable passes; verify reports `VERIFY: OK`.

- [ ] **Step 3: Inspect Files in both modes**

Launch with `./script/build_and_run.sh run`. At normal and minimum panel widths, confirm List remains default, Icons persists after relaunch, the grid changes between three and two columns, filenames do not overlap controls, and light/dark appearances retain contrast. Drag a file into the panel, drag its tile to Finder, reveal it, remove it, and use Clear.

- [ ] **Step 4: Inspect Todo creation and sorting**

Confirm `+` creates and focuses exactly one draft; a second click refocuses it; Enter adds only a non-empty title; Escape cancels; priority and date can be chosen before Add; High/Medium/Low show red/orange/gray dots plus labels in both appearances. Create overdue, today, future, and undated tasks at multiple priorities and confirm the specified order before and after relaunch.

- [ ] **Step 5: Review the final diff for scope**

Run:

```bash
git status --short
git diff main~4 --stat
git log -5 --oneline
```

Expected: only the planned settings, layout, Files UI, Todo manager/UI, tests, script, spec, and plan files changed; no generated `dist/` artifact is staged.

