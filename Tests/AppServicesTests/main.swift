import Foundation
import Cocoa
import SwiftUI

func fail(_ message: String) -> Never {
    fputs("APP SERVICES TEST FAIL: \(message)\n", stderr)
    exit(1)
}

let tempDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("overshelf-services-test-\(UUID().uuidString)")
try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

let persistence = PersistenceManager(baseURL: tempDir)

// Persistence round-trip
struct Sample: Codable {
    var value: String
}
let sample = Sample(value: "ok")
persistence.save(sample, forKey: "sample")
guard let loaded = persistence.load(Sample.self, forKey: "sample"), loaded.value == "ok" else {
    fail("persistence round-trip failed")
}

// Notes
let notes = NotesManager(persistence: persistence)
let note = notes.createNote()
notes.updateNote(id: note.id, body: "# Title\n\nBody with keyword")
guard notes.notes.first?.title == "Title" else {
    fail("Note title was not derived from body")
}
guard notes.search("keyword").count == 1 else {
    fail("Note search did not find body keyword")
}
notes.flush()
let reloadedNotes = NotesManager(persistence: persistence)
guard reloadedNotes.notes.first?.body == "# Title\n\nBody with keyword" else {
    fail("Note did not persist across reload")
}
notes.togglePin(id: note.id)
guard notes.notes.first?.pinned == true else {
    fail("Note pin did not stick")
}
notes.flush()
let pinnedNotes = NotesManager(persistence: persistence)
guard pinnedNotes.notes.first?.pinned == true else {
    fail("Note pin did not persist across reload")
}
notes.deleteNote(id: note.id)
guard notes.notes.isEmpty else {
    fail("Note delete did not remove note")
}
notes.flush()
guard NotesManager(persistence: persistence).notes.isEmpty else {
    fail("Note delete did not persist")
}

// Todos
let todos = TodoManager(persistence: persistence)
let todo = todos.createTodo(title: "Ship")
todos.flush()
guard TodoManager(persistence: persistence).items.first?.title == "Ship" else {
    fail("Todo did not persist across reload")
}
todos.toggleCompletion(id: todo.id)
guard todos.items.first?.isCompleted == true else {
    fail("Todo completion did not toggle")
}
todos.flush()
guard TodoManager(persistence: persistence).items.first?.isCompleted == true else {
    fail("Todo completion did not persist across reload")
}
todos.updatePriority(id: todo.id, priority: .high)
guard todos.items.first?.priority == .high else {
    fail("Todo priority did not update")
}
todos.flush()
guard TodoManager(persistence: persistence).items.first?.priority == .high else {
    fail("Todo priority did not persist across reload")
}
todos.deleteTodo(id: todo.id)
guard todos.items.isEmpty else {
    fail("Todo delete did not remove item")
}
todos.flush()
guard TodoManager(persistence: persistence).items.isEmpty else {
    fail("Todo delete did not persist")
}


// Todo ordering and atomic metadata creation
let todoSortDir = tempDir.appendingPathComponent("todo-sorting")
try? FileManager.default.createDirectory(at: todoSortDir, withIntermediateDirectories: true)
let sortedTodos = TodoManager(persistence: PersistenceManager(baseURL: todoSortDir))

let now = Date()
let yesterday = now.addingTimeInterval(-86400)
let tomorrow = now.addingTimeInterval(86400)

let created = sortedTodos.createTodo(title: "Urgent", priority: .high, dueDate: tomorrow)
guard created.title == "Urgent", created.priority == .high, created.dueDate == tomorrow else {
    fail("Todo creation should apply title, priority, and due date atomically")
}

let highYesterday = sortedTodos.createTodo(title: "High yesterday", priority: .high, dueDate: yesterday)
let highUndated = sortedTodos.createTodo(title: "High undated", priority: .high, dueDate: nil)
let mediumToday = sortedTodos.createTodo(title: "Medium today", priority: .medium, dueDate: now)
let completedHigh = sortedTodos.createTodo(title: "Completed high", priority: .high, dueDate: yesterday)
sortedTodos.toggleCompletion(id: completedHigh.id)

let expectedOrder: [UUID] = [highYesterday.id, created.id, highUndated.id, mediumToday.id, completedHigh.id]
guard sortedTodos.items.map(\.id) == expectedOrder else {
    fail("Todo sort order should be: incomplete high by date, then undated high, then medium, then completed")
}
sortedTodos.flush()
let reloadedSortedTodos = TodoManager(persistence: PersistenceManager(baseURL: todoSortDir))
guard reloadedSortedTodos.items.map(\.id) == expectedOrder else {
    fail("Todo sort order should survive reload")
}

// Mutation order updates
let lowToday = sortedTodos.createTodo(title: "Low today", priority: .low, dueDate: now)
sortedTodos.updatePriority(id: lowToday.id, priority: .high)
sortedTodos.updateDueDate(id: lowToday.id, dueDate: now.addingTimeInterval(-2 * 86400))
// lowToday becomes high with the earliest due date -> first
var currentOrder = sortedTodos.items.map(\.id)
guard currentOrder.first == lowToday.id else {
    fail("Raising priority and moving due date earlier should move task to the front")
}
sortedTodos.toggleCompletion(id: lowToday.id)
currentOrder = sortedTodos.items.map(\.id)
guard let lowIndex = currentOrder.firstIndex(of: lowToday.id),
      let mediumTodayIndex = currentOrder.firstIndex(of: mediumToday.id),
      lowIndex > mediumTodayIndex else {
    fail("Completing the front task should move it behind every incomplete task")
}

let mediumTomorrow = sortedTodos.createTodo(title: "Medium tomorrow", priority: .medium, dueDate: tomorrow)
sortedTodos.updateDueDate(id: mediumTomorrow.id, dueDate: nil)
currentOrder = sortedTodos.items.map(\.id)
let mediumIndex = currentOrder.firstIndex(of: mediumTomorrow.id) ?? -1
let mediumTodayIndex = currentOrder.firstIndex(of: mediumToday.id) ?? -2
// nil due date should place it after the other dated medium task, so it should appear after mediumToday
if currentOrder.contains(mediumToday.id) && currentOrder.contains(mediumTomorrow.id) {
    guard mediumIndex > mediumTodayIndex else {
        fail("Clearing a due date should move the task behind dated peers of the same priority")
    }
}


// File staging keeps references, not copies
let fileURL = tempDir.appendingPathComponent("sample-\(UUID().uuidString).txt")
try? "hello".data(using: .utf8)?.write(to: fileURL)
let files = FileStagingManager(persistence: persistence)
files.add(url: fileURL)
files.add(url: fileURL)
guard files.stagedFiles.count == 1 else {
    fail("File staging should deduplicate the same file")
}
guard files.resolveURL(for: files.stagedFiles[0])?.path == fileURL.path else {
    fail("File staging did not preserve URL")
}
let reloadedFiles = FileStagingManager(persistence: persistence)
guard reloadedFiles.stagedFiles.count == 1 else {
    fail("File staging did not persist across reload")
}
files.remove(id: files.stagedFiles[0].id)
guard files.stagedFiles.isEmpty else {
    fail("File staging did not remove file")
}

// Hidden panels disappear from the main layout.
let defaultOrder: [PanelType] = [.clipboard, .files, .notes, .todo, .workspaces]
let hidden: Set<PanelType> = [.todo]
let visible = AppSettings.visiblePanels(from: defaultOrder, hidden: hidden)
guard visible == [.clipboard, .files, .notes, .workspaces] else {
    fail("Hidden panels should be excluded from the main layout")
}
guard AppSettings.visiblePanels(from: defaultOrder, hidden: []) == defaultOrder else {
    fail("All panels should be visible when nothing is hidden")
}

// Clipboard history/favorites
let clipboard = ClipboardMonitor(persistence: persistence, limit: 10)
clipboard.recordText("hello clipboard")
guard clipboard.items.count == 1, clipboard.items.first?.text == "hello clipboard" else {
    fail("Clipboard history did not record text")
}
let clipboardHistoryReloaded = ClipboardMonitor(persistence: persistence, limit: 10)
guard clipboardHistoryReloaded.items.count == 1, clipboardHistoryReloaded.items.first?.text == "hello clipboard" else {
    fail("Clipboard history did not persist across reload")
}
let item = ClipboardItem(type: .text, text: "hello")
clipboard.toggleFavorite(item)
guard clipboard.isFavorite(item) else {
    fail("Clipboard favorite did not register")
}
let reloadedClipboard = ClipboardMonitor(persistence: persistence, limit: 10)
guard reloadedClipboard.isFavorite(item) else {
    fail("Clipboard favorite did not persist across reload")
}
clipboard.removeFromFavorites(item)
guard !clipboard.isFavorite(item) else {
    fail("Clipboard favorite did not remove")
}
clipboard.clearHistory()
guard clipboard.items.isEmpty else {
    fail("Clipboard history did not clear")
}
let clipboardAfterClear = ClipboardMonitor(persistence: persistence, limit: 10)
guard clipboardAfterClear.items.isEmpty else {
    fail("Clipboard history clear did not persist")
}

clipboard.setLimit(2)
clipboard.recordText("a")
clipboard.recordText("b")
clipboard.recordText("c")
guard clipboard.items.count == 2, clipboard.items.first?.text == "c", clipboard.items.last?.text == "b" else {
    fail("Clipboard history limit did not trim items")
}
clipboard.recordText("a")
guard clipboard.items.count == 2, clipboard.items.first?.text == "a", clipboard.items.last?.text == "c" else {
    fail("Clipboard history did not trim after inserting new item")
}
clipboard.recordText("a")
guard clipboard.items.count == 2, clipboard.items.first?.text == "a" else {
    fail("Clipboard history did not dedupe consecutive identical text")
}

print("App services test passed")
