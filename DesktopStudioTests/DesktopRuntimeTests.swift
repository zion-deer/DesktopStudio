import CoreGraphics
import XCTest
@testable import DesktopStudio

@MainActor
final class DesktopRuntimeTests: XCTestCase {
    func testCanvasPositionRoundTripsThroughAppKitCoordinates() throws {
        let display = RuntimeDisplay(id: 7, frame: CGRect(x: 100, y: 40, width: 1000, height: 500), visibleFrame: CGRect(x: 100, y: 40, width: 1000, height: 500), isMain: true)
        let fitted = CanvasScreenMapping.fit(canvasWidth: 1000, canvasHeight: 500, display: display)
        let fittedCanvas = try XCTUnwrap(fitted)
        XCTAssertEqual(fittedCanvas.scale, 1, accuracy: 0.001)
        let component = ComponentFrame(x: 10, y: 20, width: 100, height: 50, zIndex: 1)
        let window = CanvasScreenMapping.windowFrame(component: component, fitted: fittedCanvas)
        XCTAssertEqual(window.minX, 110, accuracy: 0.001)
        XCTAssertEqual(window.minY, 470, accuracy: 0.001)
        let position = CanvasScreenMapping.canvasPosition(windowFrame: window, fitted: fittedCanvas)
        XCTAssertEqual(position.x, 10, accuracy: 0.001)
        XCTAssertEqual(position.y, 20, accuracy: 0.001)
    }

    func testTwentyFourHourClockTextIsStable() {
        var settings = ComponentSettings.standard(for: .clock)
        settings.timeFormat = .twentyFourHour
        settings.showsSeconds = true
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let text = DesktopClockText.timeString(
            date: date,
            settings: settings,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertEqual(text, "22:13:20")

        settings.timeFormat = .twelveHour
        let twelve = DesktopClockText.timeString(
            date: date,
            settings: settings,
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertTrue(twelve.hasPrefix("10:13:20"))
        XCTAssertTrue(twelve.contains("PM"))
    }

    func testInvalidThemeDoesNotApplyOrCloseAnExistingExperience() {
        let harness = makeHarness()
        let report = harness.runtime.apply(theme: harness.theme)
        XCTAssertTrue(report.applied)
        XCTAssertEqual(harness.surfaces.made.count, 2)
        XCTAssertTrue(harness.runtime.isExperienceActive)

        var invalid = harness.theme
        invalid.name = " "
        let rejected = harness.runtime.apply(theme: invalid)
        XCTAssertFalse(rejected.applied)
        XCTAssertTrue(rejected.message.contains("editor is still open"))
        XCTAssertEqual(harness.surfaces.made.count, 2)
        XCTAssertFalse(harness.surfaces.made.contains(where: \.closed))
        XCTAssertTrue(harness.runtime.isExperienceActive)
    }

    func testCustomDockIsASeparateWindow() {
        let harness = makeHarness()
        harness.theme.components.append(widget(.dock, x: 20, y: 400, width: 400, height: 64))
        let report = harness.runtime.apply(theme: harness.theme)
        XCTAssertTrue(report.applied)
        XCTAssertEqual(harness.surfaces.made.count, 3)
        XCTAssertTrue(report.message.contains("does not replace the system Dock"))
        XCTAssertFalse(report.message.contains("Skipped"))
    }

    func testMoveWritesCanvasFrameAndDisplayAssignment() throws {
        let harness = makeHarness()
        _ = harness.runtime.apply(theme: harness.theme)
        let clock = try XCTUnwrap(harness.theme.components.first { $0.type == .clock })
        harness.runtime.widgetDidEndMove(componentID: clock.id, windowFrame: CGRect(x: 1040, y: 430, width: 100, height: 50))
        let saved = try harness.store.loadLibrary().themes[0]
        let moved = try XCTUnwrap(saved.components.first { $0.id == clock.id })
        XCTAssertEqual(moved.frame.x, 40, accuracy: 0.5)
        XCTAssertEqual(moved.frame.y, 20, accuracy: 0.5)
        XCTAssertEqual(moved.frame.width, 100, accuracy: 0.5)
        let session = try XCTUnwrap(harness.sessions.load())
        XCTAssertEqual(session.placements.first { $0.componentID == clock.id }?.displayID, 2)
    }

    func testDisconnectedDisplayMovesWidgetBackToTheRemainingDisplay() throws {
        let harness = makeHarness()
        _ = harness.runtime.apply(theme: harness.theme)
        let clock = try XCTUnwrap(harness.theme.components.first { $0.type == .clock })
        harness.runtime.widgetDidEndMove(componentID: clock.id, windowFrame: CGRect(x: 1010, y: 430, width: 100, height: 50))
        harness.screens.current = [primaryDisplay()]
        harness.runtime.handleScreenChange()
        let surface = try XCTUnwrap(harness.surfaces.made.first { $0.componentID == clock.id })
        let frame = try XCTUnwrap(surface.frames.last)
        XCTAssertEqual(frame.minX, 10, accuracy: 0.5)
        XCTAssertEqual(frame.minY, 430, accuracy: 0.5)
        XCTAssertTrue(surface.visible)
        XCTAssertEqual(harness.sessions.load()?.placements.first { $0.componentID == clock.id }?.displayID, 1)
    }

    func testWakeRecreatesWindowsAfterTheyWereReleased() {
        let harness = makeHarness()
        _ = harness.runtime.apply(theme: harness.theme)
        XCTAssertEqual(harness.surfaces.made.count, 2)
        harness.runtime.relinquishWindows()
        XCTAssertTrue(harness.runtime.isExperienceActive)
        harness.runtime.handleWake()
        XCTAssertEqual(harness.surfaces.made.count, 4)
        XCTAssertTrue(harness.runtime.isExperienceActive)
    }

    func testStopKeepsFramesAndRestoreReturnsTheApplySnapshot() throws {
        let harness = makeHarness()
        let clock = try XCTUnwrap(harness.theme.components.first { $0.type == .clock })
        let originalX = clock.frame.x
        _ = harness.runtime.apply(theme: harness.theme)
        harness.runtime.widgetDidEndMove(componentID: clock.id, windowFrame: CGRect(x: 80, y: 430, width: 100, height: 50))
        let stopped = harness.runtime.stopExperience()
        XCTAssertTrue(stopped.applied)
        XCTAssertFalse(harness.runtime.isExperienceActive)
        let afterStop = try harness.store.loadLibrary().themes[0]
        XCTAssertEqual(afterStop.components.first { $0.id == clock.id }?.frame.x ?? -1, 80, accuracy: 0.5)

        let restored = harness.runtime.restoreDefaultExperience()
        XCTAssertTrue(restored.applied)
        XCTAssertTrue(restored.message.contains("Dock"))
        let afterRestore = try harness.store.loadLibrary().themes[0]
        XCTAssertEqual(afterRestore.components.first { $0.id == clock.id }?.frame.x ?? -1, originalX, accuracy: 0.5)
        XCTAssertNil(harness.sessions.load())
    }

    func testSettingsEditPersistsWithoutReplacingTheSavedFrame() throws {
        let harness = makeHarness()
        _ = harness.runtime.apply(theme: harness.theme)
        let notes = try XCTUnwrap(harness.theme.components.first { $0.type == .notes })
        var settings = notes.settings
        settings.body = "Remember the display."
        harness.runtime.updateSettings(componentID: notes.id, settings: settings)
        let saved = try harness.store.loadLibrary().themes[0]
        XCTAssertEqual(saved.components.first { $0.id == notes.id }?.settings.body, "Remember the display.")
        XCTAssertEqual(saved.components.first { $0.id == notes.id }?.frame.x ?? -1, notes.frame.x, accuracy: 0.001)
    }

    func testRecoverSkipsAMissingThemeAndLeavesTheLibrary() throws {
        let harness = makeHarness()
        let stored = DesktopExperienceSession(active: true, themeID: UUID(), baseline: harness.theme, placements: [])
        harness.sessions.save(stored)
        let runtime = DesktopRuntimeController(
            themeStore: harness.store,
            sessionStore: harness.sessions,
            screens: harness.screens,
            surfaces: harness.surfaces
        )
        let report = try XCTUnwrap(runtime.recoverPersistedExperience())
        XCTAssertFalse(report.applied)
        XCTAssertTrue(report.message.contains("editor is open"))
        XCTAssertFalse(runtime.isExperienceActive)
        XCTAssertEqual(try harness.store.loadLibrary().themes.count, 1)
    }

    func testRecoverReopensTheSavedTheme() throws {
        let harness = makeHarness()
        _ = harness.runtime.apply(theme: harness.theme)
        harness.runtime.relinquishWindows()
        let reopened = RecordingSurfaceFactory()
        let runtime = DesktopRuntimeController(
            themeStore: harness.store,
            sessionStore: harness.sessions,
            screens: harness.screens,
            surfaces: reopened
        )
        let report = try XCTUnwrap(runtime.recoverPersistedExperience())
        XCTAssertTrue(report.applied)
        XCTAssertEqual(report.title, "Desktop experience restored")
        XCTAssertEqual(reopened.made.count, 2)
        XCTAssertTrue(runtime.isExperienceActive)
    }

    func testUnreadableSessionDoesNotBlockStartup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("session.json")
        try Data("{".utf8).write(to: url)
        let store = FileRuntimeSessionStore(fileURL: url)
        XCTAssertNil(store.load())

        let session = DesktopExperienceSession(active: true, themeID: UUID(), baseline: SampleTheme.blank(name: "Later"), placements: [])
        store.save(session)
        let data = try Data(contentsOf: url)
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "\"sessionVersion\" : 1", with: "\"sessionVersion\" : 99")
        text = text.replacingOccurrences(of: "\"sessionVersion\": 1", with: "\"sessionVersion\": 99")
        XCTAssertTrue(text.contains("99"))
        try Data(text.utf8).write(to: url)
        XCTAssertNil(store.load())
    }

    func testEditorStaysUsableWhenRestoreCannotFindTheTheme() {
        let theme = SampleTheme.blank(name: "Kept")
        let store = InMemoryThemeStore(themes: [theme])
        let sessions = MemoryRuntimeSessionStore()
        sessions.save(DesktopExperienceSession(active: true, themeID: UUID(), baseline: theme, placements: []))
        let runtime = DesktopRuntimeController(
            themeStore: store,
            sessionStore: sessions,
            screens: FakeScreens(current: [primaryDisplay()]),
            surfaces: RecordingSurfaceFactory()
        )
        let model = EditorModel(store: store, runtime: runtime)
        runtime.layoutSink = model
        model.finishLaunchingDesktopExperience()
        XCTAssertEqual(model.themes.map(\.name), ["Kept"])
        XCTAssertFalse(model.isDesktopExperienceActive)
        XCTAssertEqual(model.notice?.title, "Desktop experience was not restored")
        model.addComponent(.text)
        XCTAssertEqual(model.selectedTheme.components.count, 1)
    }

    func testEditorApplyStopAndMoveKeepUnsavedInspectorText() throws {
        let theme = deskTheme()
        let store = InMemoryThemeStore(themes: [theme])
        let sessions = MemoryRuntimeSessionStore()
        let surfaces = RecordingSurfaceFactory()
        let runtime = DesktopRuntimeController(
            themeStore: store,
            sessionStore: sessions,
            screens: FakeScreens(current: [primaryDisplay(), secondaryDisplay()]),
            surfaces: surfaces
        )
        let model = EditorModel(store: store, runtime: runtime)
        runtime.layoutSink = model
        model.applySelectedTheme()
        XCTAssertTrue(model.isDesktopExperienceActive)
        XCTAssertEqual(model.lastApplyReport?.applied, true)

        let notes = try XCTUnwrap(model.selectedTheme.components.first { $0.type == .notes })
        model.select(notes.id)
        model.componentBinding(\.settings.title, fallback: "", token: "title").wrappedValue = "Unsaved heading"
        XCTAssertTrue(model.isDirty)

        runtime.widgetDidEndMove(componentID: notes.id, windowFrame: CGRect(x: 80, y: 300, width: notes.frame.width, height: notes.frame.height))
        XCTAssertEqual(model.selectedTheme.components.first { $0.id == notes.id }?.settings.title, "Unsaved heading")
        XCTAssertGreaterThan(model.selectedTheme.components.first { $0.id == notes.id }?.frame.x ?? 0, notes.frame.x)

        model.stopDesktopExperience()
        XCTAssertFalse(model.isDesktopExperienceActive)
        XCTAssertEqual(model.notice?.title, "Desktop experience stopped")
    }

    private func makeHarness() -> Harness {
        let theme = deskTheme()
        let store = InMemoryThemeStore(themes: [theme])
        let sessions = MemoryRuntimeSessionStore()
        let screens = FakeScreens(current: [primaryDisplay(), secondaryDisplay()])
        let surfaces = RecordingSurfaceFactory()
        let runtime = DesktopRuntimeController(
            themeStore: store,
            sessionStore: sessions,
            screens: screens,
            surfaces: surfaces
        )
        return Harness(theme: theme, store: store, sessions: sessions, screens: screens, surfaces: surfaces, runtime: runtime)
    }

    private func deskTheme() -> Theme {
        var theme = SampleTheme.blank(name: "Desk")
        theme.canvas.width = 1000
        theme.canvas.height = 500
        theme.components = [
            widget(.clock, x: 10, y: 20, width: 100, height: 50),
            widget(.notes, x: 20, y: 80, width: 120, height: 80)
        ]
        return theme
    }

    private func widget(_ type: ComponentType, x: Double, y: Double, width: Double = 100, height: Double = 50) -> DesktopComponent {
        DesktopComponent(
            id: UUID(),
            type: type,
            name: type.libraryTitle,
            frame: ComponentFrame(x: x, y: y, width: width, height: height, zIndex: 1),
            overrides: AppearanceOverrides(),
            settings: .standard(for: type)
        )
    }

    private func primaryDisplay() -> RuntimeDisplay {
        RuntimeDisplay(
            id: 1,
            frame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 500),
            isMain: true
        )
    }

    private func secondaryDisplay() -> RuntimeDisplay {
        RuntimeDisplay(
            id: 2,
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 500),
            visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 500),
            isMain: false
        )
    }
}

@MainActor
private final class Harness {
    var theme: Theme
    var store: InMemoryThemeStore
    var sessions: MemoryRuntimeSessionStore
    var screens: FakeScreens
    var surfaces: RecordingSurfaceFactory
    var runtime: DesktopRuntimeController

    init(
        theme: Theme,
        store: InMemoryThemeStore,
        sessions: MemoryRuntimeSessionStore,
        screens: FakeScreens,
        surfaces: RecordingSurfaceFactory,
        runtime: DesktopRuntimeController
    ) {
        self.theme = theme
        self.store = store
        self.sessions = sessions
        self.screens = screens
        self.surfaces = surfaces
        self.runtime = runtime
    }
}

@MainActor
private final class FakeScreens: ScreenProviding {
    var current: [RuntimeDisplay]
    init(current: [RuntimeDisplay]) { self.current = current }
    func screens() -> [RuntimeDisplay] { current }
}

@MainActor
final class RecordingSurfaceFactory: DesktopSurfaceInstalling {
    var made: [RecordingWidgetSurface] = []

    func install(
        component: DesktopComponent,
        theme: Theme,
        windowFrame: CGRect,
        controller: DesktopRuntimeController
    ) -> DesktopWidgetSurface {
        let surface = RecordingWidgetSurface(componentID: component.id)
        surface.frames.append(windowFrame)
        made.append(surface)
        return surface
    }
}

@MainActor
final class RecordingWidgetSurface: DesktopWidgetSurface {
    let componentID: UUID
    var frames: [CGRect] = []
    var visible = true
    var closed = false
    var status: String?
    var launcherShown = false

    init(componentID: UUID) {
        self.componentID = componentID
    }

    func place(windowFrame: CGRect) { frames.append(windowFrame) }
    func update(component: DesktopComponent, theme: Theme) {}
    func orderFront() {}
    func setVisible(_ visible: Bool) { self.visible = visible }
    func setStatus(_ message: String?) { status = message }
    func setLauncherShown(_ shown: Bool) { launcherShown = shown }
    func close() { closed = true }
}
