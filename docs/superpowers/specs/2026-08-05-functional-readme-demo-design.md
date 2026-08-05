# Functional README Demo Design

## Goal

Replace the reveal-only README GIF with a short first-visit product tour. The
animation should show what OverShelf contains and what a user can accomplish,
while retaining a brief top-edge reveal as the opening context.

## Audience and Storyboard

The audience is a person seeing OverShelf for the first time. The selected
storyboard is a focused four-scene tour lasting approximately 8.5 seconds:

1. Reveal the panel from the top edge and hold the full layout briefly.
2. Focus Clipboard and show three synthetic saved items, including a favorite.
3. Focus Files and show two staged file references.
4. Focus Notes and show a selected Markdown note in preview mode.
5. Focus Todo and show priorities/dates, then one completed task.
6. Pull back to the populated four-panel overview and hold before looping.

The UI remains the source of truth. No instructional captions are composited
over the application. Panel titles, controls, selection states, and checkmarks
communicate the functions directly.

## Demo Isolation

Demo mode is selected by a documentation-only command-line argument. Before
services are initialized, the app uses `/tmp/OverShelf-ReadmeDemo` as its
persistence root and seeds only synthetic records. The normal launch path and
the user's application data are unchanged. The capture script stops all demo
processes and removes its temporary frame directory on exit.

## Scene State

`ReadmeDemoScene` parses the scene argument and exposes the active scene through
the existing UI state/environment. Services load seeded records from the demo
persistence root. Views use the scene only for presentational setup:

- Clipboard starts with safe text items and one favorite.
- Files starts with named references under the demo directory; no real file is
  copied or moved.
- Notes starts with one selected Markdown note and preview mode enabled.
- Todo starts with three tasks and one completed task.
- Overview shows all seeded data without a focused mutation.

The scene state is read-only after launch. The script creates a new process for
each scene, so no state leaks between frames.

## Capture Pipeline

`script/capture_demo.sh` will:

1. Build the app and the neutral backdrop helper.
2. Launch one isolated scene at a time with a fixed reveal progress.
3. Capture the full screen after the app settles.
4. Crop to the panel region, apply a controlled horizontal focus crop for the
   active scene, and scale to a README-safe width.
5. Assemble frames with ffmpeg palette generation and validate dimensions,
   frame count, and nonblank luminance.

The backdrop hides the user's desktop. The output must not include real browser
content, clipboard text, file names, notes, or other private data.

## Verification

- Unit-test scene parsing and demo seed contents.
- Run the complete app test suite and launch check.
- Run the capture script with Screen Recording permission.
- Verify GIF dimensions, duration, frame count, and nonblank frames.
- Extract representative Clipboard, Files, Notes, Todo, and overview frames for
  visual inspection.
- Run `git diff --check` and ensure normal launches still use the user's data
  directory.

## Constraints

- No new runtime dependencies.
- No changes to normal persistence, panel interaction, or release packaging.
- README and README.zh-CN.md continue to reference the same generated GIF.
