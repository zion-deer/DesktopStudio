# Desktop Studio

Desktop Studio is a native macOS app for designing a desktop theme. Version **0.1.0** (build 1) is a visual editor: a dark three-pane window, a component library, a display canvas, a properties inspector, and JSON themes saved on disk.

The canvas is a preview of a display. It does not change the real macOS desktop, Dock, or app launcher.

## What you can do

- Drag Clock, Text, App Shortcut, Dock, and Notes onto the display, or click them to add them.
- Select a component to see its outline and four resize handles. Drag to move it. Arrow keys nudge the selection.
- Snapping uses an 8-point grid and alignment guides against other components and the canvas. Hold Option to place a component freely.
- Zoom the preview from the canvas footer or with Command-plus, Command-minus, and Command-0. Zoom changes on-screen points only. Saved `frame` values stay in canvas coordinates.
- Edit position, dimensions, text, font size, colors, opacity, and corner radius in the inspector. Those edits update the theme model immediately.
- Undo and redo are Command-Z and Command-Shift-Z. Duplicate a component with Command-D. Delete it with the Delete key.
- Switch themes from the toolbar, or open the theme gallery to preview, create, rename, duplicate, import, export, and delete them.
- Save themes as JSON (`Command-S`).
- Edit the theme style: accent, background, type, spacing, corner radius, and the default style of each component. New components inherit that style. Customize a single field to override it, or choose Use Theme Style to inherit again.
- Start from Windows Inspired, Minimal Dark, or Futuristic. Reset Theme Style restores the style tokens. Reset Built-in Theme restores the shipped layout when you are still editing that built-in theme.
- Preview the design full size. Preview does not change your Mac.
- Choose Apply. This build always reports that nothing was applied.

Themes are stored in `~/Library/Application Support/Desktop Studio/Themes/` inside the app sandbox. The first launch installs the bundled **Night Harbor** sample.

## What this version does not do

- No floating desktop panels.
- No custom Dock and no app launcher.
- No menu-bar item, event tap, wallpaper change, or other system customization.
- App shortcuts and dock icons are visual mockups. They do not open apps.
- Reset Built-in Theme restores the original Windows Inspired, Minimal Dark, or Futuristic document. A duplicate has a new id, so it can be restyled, but it is not the shipped original.
- An existing theme library is left in place. The three built-in themes are installed when the library is empty, and they can be added later from the gallery.

`DesktopIntegrating` is the boundary for that future work. `UnavailableDesktopIntegration` is the only implementation, and its report always has `applied == false`.

The app is sandboxed and uses the user-selected file entitlement for import and export. Later desktop integration will likely need a separate, explicit entitlement or helper. This project does not request Accessibility, Screen Recording, or Apple Events.

## Requirements

- macOS 14 or later
- Xcode 15 or later, with the macOS 14 SDK

SwiftUI and AppKit are Apple platforms. This repository cannot be compiled on Linux.

## Open and build

Open `DesktopStudio.xcodeproj` and run the **Desktop Studio** scheme.

From the command line:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' -configuration Debug build
```

If automatic signing fails because no development team is selected, build locally without signing:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Run the unit tests:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' test
```

The test target is hosted in the app so it can read `SampleTheme.json` from the bundle. Tests cover JSON coding, schema 1 migration, built-in themes, inheritance, import and export, invalid documents, file persistence, undo and redo, stable component IDs, zoom conversion, alignment snapping, and the fact that Apply does not report success. The GitHub Actions workflow runs this test suite on every push and pull request.

## Version

`MARKETING_VERSION` is `0.1.0` and `CURRENT_PROJECT_VERSION` is `1`. The app reads those values as `CFBundleShortVersionString` and `CFBundleVersion`. `AppVersion` exposes the same numbers in code. See `CONTRIBUTING.md` before bumping them, and record changes in `CHANGELOG.md`.

## Continuous integration

`.github/workflows/ci.yml` builds and tests the Desktop Studio scheme on a `macos-15` runner for pushes and pull requests. It uses ad-hoc signing (`CODE_SIGN_IDENTITY=-`) and does not contain a team ID, certificate, or token. It does not create a release. The checkout action is pinned to commit `11bd71901bbe5b1630ceea73d27597364c9af683` (v4.2.2).

The workflow runs only after this repository is hosted on GitHub and Actions is enabled. A local `origin` remote does not by itself mean that workflow has executed.

## Project layout

```
DesktopStudio/
  App/             SwiftUI app, AppKit delegate, menu commands
  Design/          Colors, font mapping, SF Symbol checks
  Models/          Codable theme, component, color, and frame types
  Persistence/     JSON coding, disk store, sample theme, open/save panels
  Runtime/         Desktop integration boundary (unavailable in this version)
  Editor/          Editor state, toolbar, library, canvas, inspector, preview
  Resources/       SampleTheme.json and the asset catalog
DesktopStudioTests/
```

The editor never writes to the desktop. It talks to a `ThemeStoring` store and a `DesktopIntegrating` runtime. Tests use an in-memory store and a recording runtime.

## Theme file

A theme file is a JSON object:

- `schemaVersion` — currently `2`. Documents from schema `1` are migrated on open. Newer versions are rejected and the rest of the library still opens.
- `theme.id` — UUID.
- `theme.name`, `createdAt`, `updatedAt` — display name and ISO-8601 dates.
- `theme.canvas` — wallpaper `width`, `height`, `style` (`solid` or `gradient`), `background`, and `gradientEnd`.
- `theme.globals` — accent, background, typography, spacing, corner radius, and default `componentStyles` for each component type. Inheritance flags choose the global value or the style’s own value.
- `theme.components[]` — `id`, `type`, `name`, `frame`, `overrides`, and `settings`. An override field replaces the resolved style. Omitted fields inherit.

Component types are `clock`, `text`, `appShortcut`, `dock`, and `notes`. Colors are `{ "hex": "#RRGGBB", "opacity": 1 }`. Frames use top-left `x` and `y`, plus `width`, `height`, and `zIndex`, all in canvas coordinates. `CanvasPoint` is that saved space. `DisplayPoint` is the on-screen preview after fit-to-view and zoom. Component IDs are UUIDs and stay the same when a component is moved.

`DesktopStudio/Resources/SampleTheme.json` is the file loaded on a fresh library. `SampleTheme.make()` is the in-memory fallback if that file cannot be read. A corrupt theme in the library is skipped and reported; the rest still open.
