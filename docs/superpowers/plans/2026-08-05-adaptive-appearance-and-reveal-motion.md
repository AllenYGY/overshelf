# Adaptive Appearance and Reveal Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an opaque adaptive Light/Dark visual system and an interruptible top-edge reveal animation.

**Architecture:** Persist appearance in `AppSettings`, apply it centrally through AppKit, and expose semantic colors through `Theme`. Isolate animation math in a testable `PanelRevealAnimation` type while a clipping `NSView` owns presentation progress without resizing SwiftUI content.

**Tech Stack:** Swift 5, SwiftUI, AppKit/Core Animation, shell-driven `swiftc` tests.

---

### Task 1: Persisted Appearance Preference

**Files:**
- Modify: `OverShelf/Models/AppSettings.swift`
- Modify: `Tests/MigrationTests/main.swift`

- [ ] Add failing migration assertions that legacy settings resolve to `AppearanceMode.system` and new defaults use opacity `1.0`.
- [ ] Run `./script/build_and_run.sh test` and confirm the new assertions fail because appearance is missing or the default opacity is still `0.92`.
- [ ] Add the Codable `AppearanceMode` enum and persisted setting with backward-compatible decoding/defaulting.
- [ ] Re-run `./script/build_and_run.sh test` and confirm migration tests pass.

### Task 2: Application-Wide Appearance Application

**Files:**
- Modify: `OverShelf/App/AppDelegate.swift`
- Modify: `OverShelf/Window/WindowManager.swift`
- Modify: `OverShelf/Views/SettingsView.swift`

- [ ] Add a three-option segmented appearance picker to General > Window.
- [ ] Add one centralized mapping from `AppearanceMode` to `NSAppearance.Name?`: system `nil`, light `.aqua`, dark `.darkAqua`.
- [ ] Apply the mapping at launch and whenever the setting changes so every app-owned window updates together.
- [ ] Build the app and confirm all exhaustive switches compile.

### Task 3: Opaque Adaptive Theme

**Files:**
- Modify: `OverShelf/Views/Shared/Theme.swift`
- Review: `OverShelf/Views/ClipboardPanelView.swift`
- Review: `OverShelf/Views/FilesPanelView.swift`
- Review: `OverShelf/Views/NotesPanelView.swift`
- Review: `OverShelf/Views/TodoPanelView.swift`

- [ ] Replace `WindowBackground` material with an opaque semantic background.
- [ ] Define restrained semantic surface colors for header, fields, hover, selection, and dividers.
- [ ] Update shared and panel-local backgrounds to use those tokens consistently.
- [ ] Build and inspect source for remaining `Material`/hard-coded appearance-dependent colors.

### Task 4: Testable Reveal Animation Model

**Files:**
- Create: `OverShelf/Window/PanelRevealAnimation.swift`
- Create: `Tests/PanelRevealAnimationTests/main.swift`
- Modify: `script/build_and_run.sh`

- [ ] Add a test executable covering opening duration, closing duration, clamped progress, and reversal from current progress.
- [ ] Run the targeted test and confirm it fails because `PanelRevealAnimation` does not exist.
- [ ] Implement the minimal progress/timing model with normal durations of 0.24/0.18 seconds and reduced-motion duration of 0.10 seconds.
- [ ] Run the targeted test and full test script; confirm both pass.

### Task 5: Clipped Top-Edge Presentation

**Files:**
- Create: `OverShelf/Window/PanelRevealView.swift`
- Modify: `OverShelf/Window/WindowManager.swift`
- Modify: `OverShelf/Window/DropDownPanel.swift`

- [ ] Wrap the hosting view in a clipping AppKit container whose child remains at full target size.
- [ ] Drive reveal progress with a common-run-loop timer, updating clip height from the top and alpha without changing the panel's target frame.
- [ ] Reverse an in-flight animation from its current progress; only call `orderOut` after closing reaches zero.
- [ ] Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` with opacity-only presentation.
- [ ] Build and run rapid-toggle smoke checks to verify no jumps, blank frames, or interaction while hidden.

### Task 6: Final Verification

**Files:**
- Modify only if verification exposes a defect.

- [ ] Run `./script/build_and_run.sh test` and require all tests plus launch check to pass.
- [ ] Run `git diff --check` and inspect the scoped diff.
- [ ] Launch the app and inspect Clipboard, Files, Notes, Todo, and Settings in System, Light, and Dark modes.
- [ ] Verify opacity, panel height, rapid show/hide reversal, multiple displays, and Reduce Motion behavior; record any environment-limited checks in the handoff.
