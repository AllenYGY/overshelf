# OverShelf

A macOS dropdown-drawer app that puts clipboard history, file staging, quick
notes, and todos behind one panel that reveals from the top of your screen.

Hidden until you need it, gone the instant you're done. No Dock icon, no
desktop clutter. Built with Swift and SwiftUI.

> OverShelf is an original app inspired by the classic "dropdown drawer"
> interaction pattern. It is not affiliated with any existing product.

![OverShelf top-edge reveal](docs/screenshots/overshelf-reveal.gif)

---

## Features

### One panel, four tools

- **Clipboard history** - automatically records text, images, and files you
  copy. Browse recent items, search, star favorites, and click any entry to
  paste it back. History survives app and system restarts.
- **File staging** - a temporary holding area. Drag files in to "shelve" them,
  drag them out into any app or Finder location. Files are referenced, not
  moved or copied. A cross-window drag-and-drop transit stop.
- **Notes** - desktop-sticky quick notes, as many as you want. Full-text search,
  pin important notes, and switch between Edit and Markdown Preview (with
  KaTeX math support via `$$...$$` and `$...$`).
- **Todo** - lightweight task list with search, filters (all / active /
  completed), priorities, due dates, and one-click completion.

### Summon and dismiss

| Trigger | Action |
| --- | --- |
| `Cmd + Shift + C` | Global hotkey toggles the panel |
| `Cmd` held + mouse to top edge | Panel reveals from the top edge |
| Drag files to the top edge | Panel opens and catches the drag |

The panel reveals downward from the top edge and folds back into it when you
click outside, toggle the hotkey, or pick a menu action. The content stays at
its final size while it is revealed, avoiding the heavy full-window slide.

### Adaptive appearance

- Opaque, softly layered surfaces with no glass blur.
- Follows the macOS appearance by default.
- Override it with **System / Light / Dark** in **Preferences > General**.
- Respects the macOS **Reduce Motion** accessibility setting.

### Flexible panels

- Drag the dividers between panels to resize each one.
- Reorder panels in **Preferences > Panels**.
- Detach any panel from the panel-manager menu into its own floating,
  always-on-top window; close that window or use the menu to reattach it.
- Hide panels you don't use and restore them from **Preferences > Panels** or
  the menu bar **Panels** submenu.

### Menu bar

Click the menu bar icon (stack icon) for:

- **Show/Hide OverShelf** (`Cmd + Shift + C`)
- **New Note** / **New Todo** - create and reveal the panel
- **Clear Clipboard History**
- **Panels** - show/hide individual panels
- **Preferences...** (`Cmd + ,`)
- **Quit OverShelf** (`Cmd + Q`)

### Data and privacy

Everything is stored locally as JSON in:

```
~/Library/Application Support/OverShelf/
```

No cloud sync, no telemetry, no network calls. Your data never leaves your Mac.

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64); the current release artifact does not include Intel
  binaries
- Xcode Command Line Tools (`xcode-select --install`) only when building from
  source

---

## Install via Homebrew

The published Cask is available from the `ALLENYGY/tap` tap:

```bash
brew tap ALLENYGY/tap
brew install --cask overshelf
```

Upgrade or remove it later with:

```bash
brew upgrade --cask overshelf
brew uninstall --cask overshelf
```

To also delete clipboard history, notes, todos, and preferences:

```bash
brew uninstall --cask --zap overshelf
```

The app is currently ad-hoc signed. On first launch, macOS may require
right-clicking **OverShelf.app > Open**, or allowing it under **System Settings
> Privacy & Security**.

---

## Build and run

This project builds directly with `swiftc` (no SPM dependencies, no Xcode
project required). A single script handles compile, bundle staging, code
signing, and launch.

```bash
# Build, stage the .app bundle, and launch
./script/build_and_run.sh run

# Build only (no launch)
./script/build_and_run.sh build

# Run the test suite
./script/build_and_run.sh test

# Build and verify the app launches, then quit
./script/build_and_run.sh verify
```

The built app lands at `dist/OverShelf.app`.

First launch notes:

- The app is ad-hoc signed. macOS may show a Gatekeeper prompt the first time;
  right-click > **Open** (or **System Settings > Privacy & Security > Open
  Anyway**) to allow it.
- Top-edge and drag tracking may require **Accessibility** or **Input
  Monitoring** permission under **System Settings > Privacy & Security**. The
  Carbon global hotkey itself does not require Accessibility permission.

---

## Usage

1. Launch OverShelf. It lives in the menu bar; no Dock icon appears.
2. Press `Cmd + Shift + C` (or hold `Cmd` and move the mouse to the top edge)
   to reveal the panel.
3. Copy things, shelve files, jot notes, track tasks.
4. Click outside the panel (or press the hotkey again) to fold it away.

See the demo below, and the [Chinese readme](README.zh-CN.md) for a
localized guide.

---

## Demo

![OverShelf top-edge reveal](docs/screenshots/overshelf-reveal.gif)

Regenerate the animation from real application frames with Homebrew `ffmpeg`:

```bash
brew install ffmpeg
./script/capture_demo.sh
```

Grant **Screen Recording** permission to your terminal before running the
script. Static PNG captures can still be generated with
`script/capture_screenshots.sh`.

---

## Project layout

```
OverShelf/
  App/            # App entry, AppDelegate, status bar menu
  Models/         # AppSettings, ClipboardItem, Note, StagedFile, TodoItem
  Services/       # PersistenceManager, ClipboardMonitor, NotesManager, ...
  Views/          # Panel views, Settings, shared Markdown preview + theme
  Window/         # DropDownPanel, WindowManager, TopEdgeTracker, hotkeys
  Resources/      # AppIcon, bundled Markdown libs (markdown-it, KaTeX, DOMPurify)
Tests/            # Migration, services, edge tracker, panel frame, markdown
script/           # build, screenshot, and animated-demo scripts
dist/             # built OverShelf.app (gitignored)
```

---

## Tech notes

- **Swift / SwiftUI**, targeting macOS 14+. Uses `@Observable`, `MenuBarExtra`,
  and `Settings` scenes.
- **WebKit** powers the Markdown preview. The renderer (`markdown-it`), math
  (`KaTeX`), and sanitizer (`DOMPurify`) are bundled offline in
  `OverShelf/Resources/Markdown/` - no network, no CDNs.
- **No third-party Swift packages.** Everything is stdlib + system frameworks.
- Custom top-edge mouse tracking (`TopEdgeTracker`) and a clipped reveal state
  in `WindowManager` give the dropdown feel without private APIs.

---

## License

MIT. See [LICENSE](LICENSE). Bundled JavaScript libraries in
`OverShelf/Resources/Markdown/` carry their own licenses; see
`OverShelf/Resources/Markdown/THIRD_PARTY_NOTICES.md`.

---

## Acknowledgements

Inspired by the dropdown-drawer interaction pattern popularized by apps like
Unclutter. OverShelf is an independent implementation written from scratch.
