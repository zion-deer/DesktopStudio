# Desktop Studio

Desktop Studio is a native macOS app for designing a desktop theme. This version is the editor foundation: a dark three-pane window, a component library, a display canvas, a properties inspector, and JSON themes saved on disk.

The canvas is a preview of a display. It does not change the real macOS desktop, Dock, or app launcher.

## What you can do

- Drag Clock, Text, App Shortcut, Dock, and Notes onto the display, or click them to add them.
- Move and resize components. Hold Option to ignore the 8-point grid. Arrow keys nudge the selection.
- Edit colors, type, layout, and component-specific settings in the inspector.
- Switch themes, create, duplicate, import, export, and delete them.
- Save themes as JSON (`Command-S`).
- Preview the design full size. Preview does not change your Mac.
- Choose Apply. This build always reports that nothing was applied.

Themes are stored in `~/Library/Application Support/Desktop Studio/Themes/` inside the app sandbox. The first launch installs the bundled **Night Harbor** sample.

## What this version does not do

- No floating desktop panels.
- No custom Dock and no app launcher.
- No menu-bar item, event tap, wallpaper change, or other system customization.
- App shortcuts and dock icons are visual mockups. They do not open apps.

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

The test target is hosted in the app so it can read `SampleTheme.json` from the bundle. Tests cover JSON coding, the sample theme, file persistence, undo, and the fact that Apply does not report success.

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

- `schemaVersion` — currently `1`. Other versions are rejected.
- `theme.id` — UUID.
- `theme.name`, `createdAt`, `updatedAt` — display name and ISO-8601 dates.
- `theme.canvas` — `width`, `height`, `style` (`solid` or `gradient`), `background`, and `gradientEnd`.
- `theme.components[]` — `id`, `type`, `name`, `frame`, `appearance`, and `settings`.

Component types are `clock`, `text`, `appShortcut`, `dock`, and `notes`. Colors are `{ "hex": "#RRGGBB", "opacity": 1 }`. Frames use top-left `x` and `y`, plus `width`, `height`, and `zIndex`.

`DesktopStudio/Resources/SampleTheme.json` is the file loaded on a fresh library. `SampleTheme.make()` is the in-memory fallback if that file cannot be read. A corrupt theme in the library is skipped and reported; the rest still open.
