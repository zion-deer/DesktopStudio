# Changelog

Semantic versions follow the `MARKETING_VERSION` build setting. The build number is `CURRENT_PROJECT_VERSION`. This project is at 0.1.0.

## [Unreleased]

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
