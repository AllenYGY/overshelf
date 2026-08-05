# Adaptive Appearance and Reveal Motion Design

## Goal

Replace the translucent glass presentation with a calmer opaque layered surface, support system/light/dark appearance choices, and make the top-edge panel reveal feel immediate and spatially coherent.

## Visual System

- Use an opaque adaptive base rather than `ultraThinMaterial`.
- Use semantic macOS colors so light and dark appearances remain native and legible.
- Differentiate headers, fields, hover states, selections, and dividers with restrained luminance changes rather than transparency-heavy effects.
- Keep blue for selection and primary actions; use semantic green/red only for completion and destructive states.
- Retain the window opacity preference, but make 100% the default for new settings. Lower values affect the whole window without restoring blur.

## Appearance Preference

Add a persisted `AppearanceMode` with `system`, `light`, and `dark` cases. The default is `system`. Apply the selected appearance application-wide so the dropdown, settings window, menus, and detached panels update together. Selecting `system` clears the app override and resumes following macOS changes.

## Reveal Motion

Keep the panel at its final screen frame while animating a clipped content container from the top edge downward. Content retains its full layout size during the animation, preventing fields and panel columns from reflowing. Opening lasts approximately 240 ms and includes a subtle opacity ramp. Closing reverses the reveal in approximately 180 ms and orders the panel out only after the animation completes.

Animation must be interruptible. A show request during closing and a hide request during opening reverse from the current progress instead of jumping to an endpoint. When Reduce Motion is enabled, use a roughly 100 ms opacity-only transition.

## Settings

In Settings > General > Window:

- Add a segmented `System / Light / Dark` appearance picker.
- Keep the opacity slider.
- Keep the existing height and keep-on-top settings.

## Compatibility

Existing settings without an appearance value decode as `system`. Existing stored opacity remains unchanged; only new installs/default settings use 1.0. Detached panel behavior is preserved.

## Verification

- Persistence and migration tests for appearance and opacity defaults.
- Unit tests for reveal progress, reversal, and reduced-motion timing.
- Full build and existing service tests.
- Manual Light/Dark inspection of all four panels and Settings.
- Manual rapid toggle, variable-height, multi-display, and Reduce Motion checks.
