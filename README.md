# Desktop Studio

Desktop Studio is a native macOS app for designing a desktop theme and showing it in widget windows. Version **0.1.0** (build 1) includes the editor and the first desktop runtime.

The canvas is still the design surface. Apply is what opens windows. Those windows belong to Desktop Studio. They do not replace the Dock, menu bar, Finder, wallpaper, or any system file.

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
- Preview the design full size. Preview does not open desktop windows.
- Choose Apply to open the theme’s clock, text, notes, app shortcuts, custom dock, and launcher as separate windows. The launcher stays hidden until you open it, so it does not take keyboard focus when you apply a theme. The custom dock does not replace the macOS Dock.
- Drag a widget by its grip. The new position is saved into the theme as canvas coordinates. A dock snaps to the edge you chose (top, bottom, left, or right) and can be aligned to the start, center, or end of that edge. Dropping another widget on a second display remembers that display until the display is disconnected.
- On a clock, use the context menu for 12-hour, 24-hour, or system time, and to show the date or seconds. Text has an Edit button. Notes has a Save note button. An app shortcut opens its bundle identifier with `NSWorkspace` when that app is installed.
- The dock has a search button that opens the theme’s launcher. Theme → Open Launcher does the same thing, as does the launcher shortcut (Option-Command-Space unless you change it). Escape or Close dismisses it. Search matches application names and bundle identifiers from `/Applications`, `/System/Applications`, and your `Applications` folder. Pinned favorites are stored in the theme, including a group name. Missing or empty bundle identifiers stay in the list and do not launch. The sandbox may be unable to read some of those folders; the launcher says so instead of claiming a complete catalog.
- Open Desktop Studio at login is optional. Apply, or the dock’s context menu, uses `SMAppService` and may send you to System Settings to approve it. Stop does not remove that login item. Restore Default Experience puts the checkbox back to the value from the last Apply.
- Choose Stop Desktop Experience (toolbar, or Theme menu, Command-Shift-Period) to close those windows. Saved positions stay in the theme.
- Choose Restore Default Experience in the Theme menu to close the windows and put widget positions and text back to the theme as it was when you last chose Apply. This does not restore or change the macOS Dock, because Desktop Studio never modifies it.

Themes are stored in `~/Library/Application Support/Desktop Studio/Themes/` inside the app sandbox. The first launch installs the bundled **Night Harbor** sample. While a desktop experience is active, `~/Library/Application Support/Desktop Studio/Runtime/session.json` remembers the theme id, the Apply-time snapshot, and which display each widget is on. That file is not a theme.

## What this version does not do

- It does not replace, hide, or resize the macOS Dock, menu bar, Finder, wallpaper, desktop picture, or protected system files. The custom dock is its own window.
- It does not install a menu-bar extra, an event tap, or a keyboard hook. Clicks outside a widget go to the window behind it. Keyboard input goes to the widget only while that widget is key, which notes and text need for typing.
- Widget windows use the public floating window level, with `canJoinAllSpaces`, `fullScreenAuxiliary`, and `stationary`. They can cover part of a normal window if you leave them there. They are not guaranteed to stay visible over an exclusive fullscreen app, and Stage Manager can still group or hide them. There is no public API to opt out of Stage Manager.
- The custom dock is placed inside the display’s visible frame, so it sits beside the menu bar and the system Dock instead of covering them. It does not reserve space the way the system Dock does, and other windows can cover it. Left, right, top, and bottom edges use that visible frame. Exclusive fullscreen can hide the window. A fullscreen Space that allows auxiliary windows may show it. Stage Manager can still group it with Desktop Studio.
- App shortcuts and dock icons ask `NSWorkspace` to open an installed app. The sandbox can still refuse that launch. The widget shows the error. The project does not add an Apple Events entitlement. A moved app is found only when Launch Services still knows its bundle identifier. A deleted app is shown as unavailable. Themes never store file paths.
- The runtime does not resize widgets. Change size in the editor, then Apply again.
- Inspector edits made after Apply are not pushed to open windows until the next Apply. Edits made on a widget are saved into the theme. That save includes other unsaved edits already in the editor for the same theme.
- Closing the editor window quits the app, which closes widget windows with it. If you did not choose Stop, the next launch opens them again. If the theme is missing or invalid, launch continues and the editor explains why the windows were not restored.
- Reset Built-in Theme restores the original Windows Inspired, Minimal Dark, or Futuristic document. A duplicate has a new id, so it can be restyled, but it is not the shipped original.
- An existing theme library is left in place. The three built-in themes are installed when the library is empty, and they can be added later from the gallery.

`DesktopIntegrating` is the runtime boundary. The app uses `DesktopRuntimeController`. Previews and unit tests that do not pass a runtime still use `UnavailableDesktopIntegration`, whose Apply report has `applied == false`.

The app is sandboxed and uses the user-selected file entitlement for import and export. It does not request Accessibility or Screen Recording.

## Manual checks for windows

Automated tests cover validation, coordinate conversion, dock layout, launcher search and favorites, saving a move, display disconnect, wake recreation, stop versus restore, and a missing theme at launch. These checks need a Mac and are not run in CI:

1. Apply a theme that has a clock, text, notes, an app shortcut, and a dock. Confirm one window each. Confirm the system Dock and menu bar are unchanged.
2. Pin an app with Choose Application. Launch it from the dock and with the keyboard (Tab, then Space or Return). Unpin it and confirm the icon leaves the dock but stays in the inspector. Point a bundle identifier at an app that is not installed and confirm the icon is dimmed.
3. Change icon size, spacing, padding, alignment, and edge, then Apply. Drag the dock along that edge. Quit and relaunch. Confirm the dock returns. Choose Stop, relaunch, and confirm it stays closed. Switch themes and confirm the dock matches the new theme.
4. Turn on Open at Login and Apply. If macOS asks, approve Desktop Studio in System Settings. Confirm the system Dock did not change. Stop the experience and confirm the login item is still the one you approved until you turn the setting off and Apply, or Restore Default Experience to a snapshot that had it off.
5. Move a widget, then choose Restore Default Experience. Confirm it returns to the position from the last Apply.
6. Apply, then unplug a display the widget was on. Confirm the widget appears on the remaining display. Plug the display back in. The widget stays on the display it was moved to; it does not jump back by itself.
7. Apply, sleep the Mac, and wake it. Confirm the windows are still in place and the clock time is current.
8. Open a normal app and type. Confirm the keyboard reaches that app until you click a notes, text, or dock widget.
9. Enter Mission Control, switch Spaces, and turn on Stage Manager. Note whether the widgets stay visible. Fullscreen an app. Auxiliary fullscreen spaces may show the widgets; exclusive fullscreen can hide them. Leaving fullscreen should show them again. The custom dock will not sit on top of the system Dock’s reserved strip.
10. Rename a theme file’s JSON so it is invalid, or remove the applied theme, then relaunch. The editor should open and report that the desktop experience was not restored.
11. Add a Launcher, pin an app, Apply, and open it from the dock button, Theme → Open Launcher, and Option-Command-Space. Type to filter. Use the arrow keys and Return. Press Escape. Confirm it did not appear, and did not take focus, until you opened it. Switch Spaces, fullscreen an app, and unplug a display. The panel should come back on the remaining display after you leave fullscreen. It will not cover the system Dock.

## Requirements

- macOS 14 or later
- Xcode 15 or later (Xcode 27 tested), with the macOS 14 SDK

SwiftUI and AppKit are Apple platforms. This repository cannot be compiled on Linux.

## Open and build

Clone the repo (for example with [Origin](https://cursor.com/docs/cli/overview)) and work from the folder that contains `DesktopStudio.xcodeproj`:

```bash
cd ~/DesktopStudio
```

Open `DesktopStudio.xcodeproj` and run the **Desktop Studio** scheme.

From the command line:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' -configuration Debug build
```

If automatic signing fails because no development team is selected, build locally without signing:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

### Xcode 27 and “not a valid property list”

If `xcodebuild` reports that the project is not a valid property list (often with a JSON parse error), the usual causes are a stale clone or a damaged `project.pbxproj`. Pull the latest `main`, then check the project file:

```bash
cd ~/DesktopStudio
git pull origin main
file DesktopStudio.xcodeproj/project.pbxproj   # should say "ASCII text"
wc -c DesktopStudio.xcodeproj/project.pbxproj  # about 40000 bytes
head -1 DesktopStudio.xcodeproj/project.pbxproj # // !$*UTF8*$!
```

Ensure the active developer directory is the full Xcode app (not Command Line Tools only):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

List schemes to confirm the project loads:

```bash
xcodebuild -list -project DesktopStudio.xcodeproj
```

In Xcode 27, you can also select the project in the navigator, open the File inspector, and leave **Project Format** on the property list format unless you intentionally migrate to JSON.

Run the unit tests:

```bash
xcodebuild -project DesktopStudio.xcodeproj -scheme DesktopStudio -destination 'platform=macOS' test
```

The test target is hosted in the app so it can read `SampleTheme.json` from the bundle. Tests cover JSON coding, schema 1 migration, built-in themes, inheritance, import and export, invalid documents, file persistence, undo and redo, stable component IDs, zoom conversion, alignment snapping, the unavailable runtime used by older editor tests, and the desktop runtime (validation, placement, display loss, wake, stop, and restore). The GitHub Actions workflow runs this test suite on every push and pull request. It does not run the manual window checks above, and it does not publish a release. Signed updates are described in `docs/UPDATES.md`.

## Version

`MARKETING_VERSION` is `0.1.0` and `CURRENT_PROJECT_VERSION` is `1`. The app reads those values as `CFBundleShortVersionString` and `CFBundleVersion`. `AppVersion` exposes the same numbers in code. Sparkle compares the build number when it looks for an update. See `CONTRIBUTING.md` before bumping them, and record changes in `CHANGELOG.md`.

## Updates

Published copies check a Sparkle appcast and install a later Developer ID release from GitHub Releases. The feed URL and Ed25519 public key are empty in a local build, so that copy does not check for updates. Configuration, secrets, and the first test release are in `docs/UPDATES.md`.

## Continuous integration

`.github/workflows/ci.yml` builds and tests the Desktop Studio scheme on a `macos-15` runner for pushes and pull requests. It also runs the release-rule unit tests. It uses ad-hoc signing (`CODE_SIGN_IDENTITY=-`) and does not contain a team ID, certificate, or token. It does not create a release. `.github/workflows/release.yml` publishes a signed update only when a version tag is pushed or the workflow is started by hand. The checkout action is pinned to commit `11bd71901bbe5b1630ceea73d27597364c9af683` (v4.2.2).

The workflow runs only after this repository is hosted on GitHub and Actions is enabled. A local `origin` remote does not by itself mean that workflow has executed.

## Project layout

```
DesktopStudio/
  App/             SwiftUI app, AppKit delegate, menu commands
  Design/          Colors, font mapping, SF Symbol checks
  Models/          Codable theme, component, color, and frame types
  Persistence/     JSON coding, disk store, sample theme, open/save panels
  Runtime/         Desktop windows for clock, text, notes, and app shortcuts
  Editor/          Editor state, toolbar, library, canvas, inspector, preview
  Resources/       SampleTheme.json and the asset catalog
DesktopStudioTests/
```

The editor talks to a `ThemeStoring` store and a `DesktopIntegrating` runtime. Tests use an in-memory store. Editor tests that only check Apply’s refusal use `UnavailableDesktopIntegration`. Desktop runtime tests use a fake display list and fake windows so they do not need a connected monitor.

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
