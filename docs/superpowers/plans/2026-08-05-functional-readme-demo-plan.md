# Functional README Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the reveal-only README GIF with an 8.5-second first-visit tour that visibly demonstrates Clipboard, Files, Notes, Todo, and the full four-panel overview.

**Architecture:** Add a small read-only demo-scene model in `OverShelf/Models/ReadmeDemo.swift`. `AppDelegate` seeds synthetic Codable stores before service initialization when `--readme-demo-scene=` is present, and `UIState` exposes the scene so Notes can open preview mode deterministically. The capture script launches isolated processes, crops/focuses the real panel, and assembles validated frames with ffmpeg.

**Tech Stack:** Swift 5, SwiftUI/AppKit, existing `PersistenceManager` and service stores, Bash, ffmpeg.

---

### Task 1: Scene Parsing and Synthetic Stores

**Files:** Create `OverShelf/Models/ReadmeDemo.swift` and `Tests/ReadmeDemoTests/main.swift`; modify `OverShelf/App/AppDelegate.swift` and `script/build_and_run.sh`.

- [ ] **Step 1: Write the failing test.** The standalone test must assert `ReadmeDemoScene.parse(arguments: ["OverShelf", "--readme-demo-scene=notes"]) == .notes`, no argument returns `nil`, and `ReadmeDemoData.seed(scene: .overview, into: persistence)` writes 3 clipboard items, 2 staged files, one note whose body contains `# Launch notes`, and at least one completed todo.
- [ ] **Step 2: Run the focused test and verify it fails.** Run `./script/build_and_run.sh test`; expect compilation failure because the scene and seed types do not exist.
- [ ] **Step 3: Implement the minimal model.** Define `ReadmeDemoScene: String, CaseIterable` with `clipboard`, `files`, `notes`, `todo`, and `overview`. Add `static parse(arguments:)` for the `--readme-demo-scene=` prefix. Add `ReadmeDemoData.seed(scene:into:)` that writes `ClipboardHistoryStore`, `StagedFilesStore`, `NotesStore`, and `TodoStore` using fixed dates and synthetic values: `https://overshelf.app/docs`, `#1F6FEB`, `Review the launch checklist`, `Launch-Brief.pdf`, `App-Icon.sketch`, a Markdown `# Launch notes` checklist, and `Polish the README` / `Publish the build` / `Update Homebrew` todos. Use `/tmp/OverShelf-ReadmeDemo/...` URLs only; never create or copy those files.
- [ ] **Step 4: Integrate before service initialization.** Parse the scene in `AppDelegate.init()`, select the existing temporary persistence root, call `ReadmeDemoData.seed` before constructing managers, and leave clipboard monitoring disabled for all demo scenes. Normal launches must take the existing path unchanged.
- [ ] **Step 5: Add the focused executable to `script/build_and_run.sh` and rerun the full suite.** Expected output includes `Readme demo tests passed` and all existing tests pass.
- [ ] **Step 6: Commit.** `git add OverShelf/Models/ReadmeDemo.swift OverShelf/App/AppDelegate.swift Tests/ReadmeDemoTests/main.swift script/build_and_run.sh && git commit -m "Seed isolated functional README demo scenes"`.

### Task 2: Deterministic Notes and Window State

**Files:** Modify `OverShelf/Window/WindowManager.swift`, `OverShelf/Views/NotesPanelView.swift`, and `OverShelf/Views/MainContentView.swift` only if environment wiring is needed; extend `Tests/ReadmeDemoTests/main.swift`.

- [ ] **Step 1: Add `readmeDemoScene: ReadmeDemoScene?` to `UIState`.** Assign it before `WindowManager` creates `MainContentView`; preserve the existing environment chain for normal launches.
- [ ] **Step 2: Make Notes deterministic only in demo mode.** In `NotesPanelView`, on first appearance when the scene is `.notes` or `.overview`, select the seeded note, copy its body into `noteBody`, and set `isPreviewing = true`; never run this branch for normal launches.
- [ ] **Step 3: Extend `WindowManager.showDemoFrame`.** Accept an optional scene while preserving the current progress-only call. Keep the panel noninteractive and never invoke clipboard copy, file staging, or todo mutation.
- [ ] **Step 4: Run a manual scene smoke check.** Build, then run `open -n dist/OverShelf.app --args "--readme-demo-scene=notes --readme-demo-frame=1"`; verify the synthetic Markdown note is selected in Preview mode and the normal data directory is untouched.
- [ ] **Step 5: Commit.** `git add OverShelf/Window/WindowManager.swift OverShelf/Views/NotesPanelView.swift OverShelf/Views/MainContentView.swift Tests/ReadmeDemoTests/main.swift && git commit -m "Make functional demo scenes render deterministic panel states"`.

### Task 3: Four-Scene Capture Pipeline

**Files:** Modify `script/capture_demo.sh` and `script/DemoBackdrop.swift` only if backdrop layering needs correction; regenerate `docs/screenshots/overshelf-reveal.gif`.

- [ ] **Step 1: Add scene-aware capture helpers.** Make `capture_progress` accept `scene`, `progress`, and `name`, launch both `--readme-demo-scene=clipboard` (substituting the function's scene argument) and `--readme-demo-frame=1` (substituting its progress argument), and retain the nonblank luminance guard.
- [ ] **Step 2: Generate the exact sequence.** Capture hidden overview; opening overview at `0.15`, `0.45`, `0.75`, `1.0`; focused Clipboard, Files, Notes, and Todo scenes at `1.0`; full overview at `1.0`; closing overview at `0.75`, `0.40`, `0.10`; and hidden overview. Hold focused frames long enough to read and hold the final overview before closing.
- [ ] **Step 3: Add deterministic focus crops.** Use ffmpeg crop/pad expressions that preserve one output size while selecting one quarter of the full-width panel for each focused scene. Never resize the GIF canvas between frames.
- [ ] **Step 4: Rebuild and inspect.** Run `./script/capture_demo.sh`, then `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,nb_frames,duration -of default=nw=1 docs/screenshots/overshelf-reveal.gif` and extract representative frames with ffmpeg. Verify readable synthetic Clipboard, Files, Notes, Todo states, no desktop content, and a final four-panel overview.
- [ ] **Step 5: Commit.** `git add script/capture_demo.sh script/DemoBackdrop.swift docs/screenshots/overshelf-reveal.gif && git commit -m "Show functional panel workflows in the README demo"`.

### Task 4: Documentation and Release Safety

**Files:** Modify `README.md` and `README.zh-CN.md` only if references need correction; test `Tests/ReadmeDemoTests/main.swift`.

- [ ] **Step 1: Check references.** Run `rg -n "overshelf-reveal.gif|capture_demo.sh|App.png" README.md README.zh-CN.md`; both READMEs must reference `overshelf-reveal.gif`, with no stale `App.png` in the committed content.
- [ ] **Step 2: Run complete verification.** Run `./script/build_and_run.sh test`, `git diff --check`, `bash -n script/capture_demo.sh`, and `plutil -lint OverShelf/Info.plist`; all must exit 0.
- [ ] **Step 3: Confirm normal launch isolation.** Run `./script/build_and_run.sh verify`; the normal launch check must pass without the demo argument or demo persistence path.
- [ ] **Step 4: Commit documentation only if changed.** `git add README.md README.zh-CN.md && git commit -m "Document the functional README demo workflow"`.
