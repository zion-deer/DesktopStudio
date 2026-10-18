# Changelog

Semantic versions follow the `MARKETING_VERSION` build setting. The build number is `CURRENT_PROJECT_VERSION`. This project is at 0.1.0.

## [Unreleased]

- Desktop runtime that opens one native window per clock, text, notes, app-shortcut, and custom dock component.
- Custom dock with pinned apps, bundle identifiers, icon size, spacing, padding, alignment, and screen edge. Appearance still controls background, opacity, and corner radius. Hover scales an icon. Tab and Space or Return launch it. Choose Application stores a bundle identifier from the system file picker and does not store a path. Missing apps stay visible but do not launch.
- Optional Desktop Studio login item through `SMAppService`. macOS may require approval in System Settings. The system Dock is never modified.
- Launcher panel with typed search, icons, pinned favorites in groups, arrow keys, and Return to launch. It stays hidden until opened from the dock, the Theme menu, or Option-Command-Space. Discovery reads Applications folders only. Missing bundle identifiers do not launch.
- Apply validates the theme first. An invalid theme does not open windows and does not close windows that are already showing. The editor still opens.
- Dragging a widget writes its canvas position back into the theme file. The display it was dropped on is stored in `~/Library/Application Support/Desktop Studio/Runtime/session.json`.
- Clock widgets format the time and can switch 12-hour, 24-hour, or system time, with optional date and seconds. Text and notes can be edited on the widget. App shortcuts open an installed app through `NSWorkspace`.
- Display changes and wake re-place widgets. A missing display moves that widget onto the main display, still using its canvas position. An active session is restored after the app launches again.
- Stop Desktop Experience closes widget windows and leaves saved theme content in place. Restore Default Experience closes them and writes back the theme snapshot from the moment Apply was chosen. Stop does not remove a login item.
- The macOS Dock, menu bar, Finder, wallpaper, and system files are not modified. No Accessibility, Screen Recording, or Apple Events permission is requested.
- Sparkle 2.10 checks a signed appcast for published releases. A local build leaves the feed empty and does not check. Themes stay in Application Support when an update replaces the app.
- GitHub Actions keeps build-and-test separate from the release workflow. Only a version tag, or a manual run of that workflow, can publish a Developer ID archive.

- Schema 2 theme documents with global accent, background, typography, spacing, corner radius, and default component styles.
- Components inherit that style and can override individual fields.
- Theme gallery with previews, plus create, rename, duplicate, delete, import, and export.
- Built-in Windows Inspired, Minimal Dark, and Futuristic themes, with reset to the shipped original.
- Schema 1 documents migrate on open. Unknown component types are skipped. Unsupported schema versions are rejected without stopping the rest of the library.
- Import checks reject oversized files, malformed JSON, duplicate IDs, invalid colors and dimensions, path-like identifiers, and executable content.
- Canvas zoom that changes only the on-screen preview.
- Alignment guides while moving and resizing, in addition to the 8-point grid.
- Resize handles on all four corners.
- Explicit canvas coordinates and display coordinates.
- Tests for layout snapping, zoom conversion, stable component IDs, and JSON serialization.
- GitHub Actions workflow that builds and tests on a macOS runner.

## [0.1.0] - 2026-10-18

- Dark three-pane theme editor for Clock, Text, App Shortcut, Dock, and Notes.
- Drag, select, resize, inspector editing, undo, duplicate, and delete.
- JSON theme library with the Night Harbor sample.
- Preview and an Apply action that reports desktop integration is not connected.
