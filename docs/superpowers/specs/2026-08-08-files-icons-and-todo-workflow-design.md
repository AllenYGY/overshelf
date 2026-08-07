# Files Icons and Todo Workflow Design

## Context

OverShelf currently shows staged files only as rows. The Todo panel combines Search and New Task inputs in one compact row, creates tasks with incomplete metadata, and sorts equal-status tasks by priority followed by modification time. The next update adds an icon view for Files and makes Todo creation and ordering more deliberate without changing the app's local-only persistence model.

## Goals

- Add a discoverable List / Icons view switch to Files.
- Remember the user's selected Files view across launches while keeping List as the default.
- Preserve file drag-in, drag-out, Finder reveal, removal, Clear, and item count behavior in both views.
- Replace the cramped Todo creation field with one focused inline draft.
- Allow priority and due date selection before a Todo is persisted.
- Sort tasks predictably by completion state, priority, and due-date proximity.
- Use consistent, accessible priority colors in existing rows and the new draft row.

## Non-Goals

- File selection, multi-select, keyboard range selection, or Finder-style lasso selection.
- User-controlled icon size or grid density.
- Manual Todo reordering that overrides the defined sort order.
- Recurring tasks, reminders, tags, or additional Todo fields.
- Changes to workspace reference behavior or the other panels.

## Files Panel

### View Mode Control

The Files header gains a compact icon-only segmented control on its trailing edge:

- `list.bullet` selects List.
- `square.grid.2x2` selects Icons.
- Tooltips identify both controls.
- The selected mode uses the app accent color and a distinct selected surface.

List remains the default for new and migrated settings. A user selection is persisted in `AppSettingsData` through an optional Codable field so older settings decode without resetting unrelated preferences. Migration fills a missing value with List.

### Icons Layout

Icons mode uses a vertical `ScrollView` containing an adaptive `LazyVGrid`:

- Minimum tile width is sized to produce three columns at the normal Files panel width.
- Narrow panels automatically reduce to two columns.
- File icons render at approximately 44 points.
- Names use up to two centered lines with middle truncation.
- Tile dimensions remain stable while hover actions appear.

The tile uses the resolved file URL to request the native macOS file icon. If the URL or icon is unavailable, it displays the existing document fallback symbol.

### File Interactions

- The whole tile is a drag source using the same URL provider as List rows.
- Hover reveals a compact Show in Finder control without resizing the tile.
- The context menu provides Show in Finder and Remove.
- Panel-wide file dropping behaves identically in both modes.
- The footer continues to show the item count and Clear action.
- Switching modes does not reorder or mutate staged files.

## Todo Panel

### Inline Draft Creation

The Todo header gains a trailing `+` button. Search becomes a full-width field below the header; the permanent New Task field is removed.

Clicking `+` inserts one inline draft at the top of the list and focuses its title field. The draft owns temporary title, priority, and due-date state. Its default priority is Medium and its due date is empty.

The draft provides:

- A focused title field.
- The existing compact priority menu.
- The compact due-date calendar and quick-date actions.
- An Add command.
- A Cancel command.

Keyboard behavior:

- Enter creates the task when the trimmed title is non-empty.
- Escape cancels and clears the draft.
- Enter with an empty title does nothing.
- Clicking `+` while a draft is already open refocuses the existing draft instead of creating another.

No `TodoItem` is created or persisted until Add or a valid Enter submission. After creation, the draft closes and the new item is placed by the normal sort order.

### Todo Manager API

`TodoManager.createTodo` accepts title, priority, and due date as creation parameters, with existing defaults retained for callers such as the menu bar action. This keeps draft state in the view and ensures one atomic creation operation reaches persistence.

### Priority Colors

Priority uses one consistent visual vocabulary everywhere:

- High: red.
- Medium: amber/orange.
- Low: cool gray.

Rows and the draft show both a colored dot and the text label. Color remains supplementary so priority is still understandable without color perception. Completed rows reduce overall emphasis but retain the priority label and color meaning.

### Sort Order

Todos use a total, deterministic order:

1. Incomplete tasks before completed tasks.
2. Within the same completion state: High, then Medium, then Low.
3. Within the same priority: dated tasks before undated tasks.
4. Dated tasks sort by due date ascending, which naturally places overdue dates first, then today, then the nearest future date, then more distant dates.
5. Equal due dates sort by `modifiedAt` descending.
6. Remaining ties sort by `createdAt` descending, then UUID string ascending.

Sorting is applied after creation, completion changes, priority changes, due-date changes, and disk loading. Search and All / Active / Completed filters preserve this manager-provided order.

## Error and Edge Handling

- Missing or inaccessible staged-file URLs keep the fallback icon and do not crash the grid.
- Show in Finder remains a no-op if URL resolution fails, matching current behavior.
- Duplicate dropped files continue to be rejected by `FileStagingManager`.
- An empty or whitespace-only draft cannot create a task.
- Closing or hiding the panel with an unsubmitted draft does not persist a partial Todo.
- Missing Files view-mode settings migrate to List without resetting other stored settings.

## Testing

### Settings and Files

- Legacy settings without a Files view mode migrate to List.
- An Icons selection persists across reload.
- Pure grid-column calculations cover normal and narrow panel widths.
- Existing file staging persistence, duplicate prevention, removal, and URL resolution tests remain green.

### Todo Creation and Sorting

- Atomic creation persists title, priority, and due date together.
- Empty draft behavior is covered by view-state or extracted pure-state tests without creating a Todo.
- Completion grouping precedes priority ordering.
- High precedes Medium, and Medium precedes Low.
- Within a priority, overdue and nearer due dates precede later dates.
- Undated tasks sort after dated tasks.
- Equal due dates use modification time, creation time, and UUID fallback deterministically.
- Sorting is verified after load and each manager mutation that can affect order.

### Verification

- Run the full `./script/build_and_run.sh test` suite.
- Build and launch the app with `./script/build_and_run.sh verify`.
- Visually inspect List and Icons modes at narrow and normal Files widths.
- Visually inspect the Todo draft, keyboard submission/cancellation, priority colors, and due-date ordering in both light and dark appearances.

