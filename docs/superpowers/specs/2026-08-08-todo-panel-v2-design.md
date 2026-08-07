# Todo Panel V2 Design

## Context
The current Todo panel uses a dropdown priority menu in the draft row, an always-empty date picker, and hover actions that include a redundant pencil. This update makes creation and scanning faster while keeping the local-only persistence model.

## Goals
- Turn the draft row into a quick-entry card with inline priority and date chips.
- Support Add, Add & New, and Cancel with keyboard equivalents (Enter, Cmd+Enter, Esc).
- Show relative due dates with overdue tasks highlighted in red.
- Remove the redundant pencil hover action.
- Show counts in the filter bar (All / Active / Done).
- Keep the existing deterministic sort order.

## Non-Goals
- Recurring tasks, reminders, tags, or additional fields.
- Changing the underlying TodoItem model or persistence format.
- Altering other panels.

## Components
- `TodoPanelView`: owns draft state, search, filter, and the visible list.
- `TodoDraftRow`: quick-entry card with title field, H/M/L priority buttons, date chips (Today / Tomorrow / +1 Week / Custom), and action buttons.
- `TodoRow`: simplified metadata line (colored dot + label + relative date) and reduced hover actions (calendar, trash).

## Interaction
- Clicking `+` in the header opens a focused draft card.
- Enter submits and closes; Cmd+Enter submits and opens a new draft; Esc cancels.
- Clicking a date chip sets the date immediately; Custom opens the existing calendar popover.
- Completed tasks keep their priority label and color but are visually de-emphasized.

## Testing
- Existing service tests remain green.
- Manual QA covers keyboard flow, continuous add, light/dark mode, and hover behavior.
