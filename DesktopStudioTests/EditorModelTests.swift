import CoreGraphics
import XCTest
@testable import DesktopStudio

@MainActor
final class EditorModelTests: XCTestCase {
    func testAddClockSelectsAndClamps() {
        let model = makeModel(themes: [SampleTheme.blank(name: "Blank")])
        model.addComponent(.clock, centeredAt: CGPoint(x: -100, y: -100))
        XCTAssertEqual(model.selectedTheme.components.count, 1)
        XCTAssertEqual(model.selectedComponent?.type, .clock)
        let frame = model.selectedComponent?.frame
        XCTAssertGreaterThanOrEqual(frame?.x ?? -1, 0)
        XCTAssertGreaterThanOrEqual(frame?.y ?? -1, 0)
        XCTAssertTrue(model.isDirty)
    }

    func testUndoRestoresDeletedComponent() {
        let model = makeModel(themes: [SampleTheme.make()])
        let original = model.selectedTheme.components.count
        let id = model.orderedComponents[0].id
        model.deleteComponent(id: id)
        XCTAssertEqual(model.selectedTheme.components.count, original - 1)
        model.undo()
        XCTAssertEqual(model.selectedTheme.components.count, original)
        XCTAssertFalse(model.isDirty)
    }

    func testSaveClearsTheDirtyFlag() throws {
        let store = InMemoryThemeStore(themes: [SampleTheme.blank(name: "Blank")])
        let model = EditorModel(store: store)
        model.addComponent(.notes)
        XCTAssertTrue(model.isDirty)
        model.saveSelectedTheme()
        XCTAssertFalse(model.isDirty)
        XCTAssertNil(model.notice)
        let loaded = try store.loadLibrary()
        XCTAssertEqual(loaded.themes[0].components.count, 1)
        XCTAssertEqual(loaded.themes[0].components[0].type, .notes)
    }

    func testNewThemeUsesADistinctName() {
        let model = makeModel(themes: [SampleTheme.blank(name: "Untitled Theme")])
        model.newTheme()
        XCTAssertEqual(model.selectedTheme.name, "Untitled Theme 2")
        XCTAssertEqual(model.themes.count, 2)
        XCTAssertFalse(model.isDirty)
    }

    func testApplyDoesNotReportSuccess() {
        let runtime = RecordingDesktopIntegration()
        let model = EditorModel(
            store: InMemoryThemeStore(themes: [SampleTheme.blank(name: "Blank")]),
            runtime: runtime
        )
        model.applySelectedTheme()
        XCTAssertEqual(runtime.appliedNames, ["Blank"])
        XCTAssertEqual(model.lastApplyReport?.applied, false)
        XCTAssertEqual(model.notice?.title, "Nothing was applied")
        XCTAssertTrue(model.lastApplyReport?.message.contains("does not place floating surfaces") == true)
    }

    func testLibraryFailureFallsBackToSample() {
        let model = EditorModel(store: FailingThemeStore())
        XCTAssertEqual(model.selectedTheme.name, "Night Harbor")
        XCTAssertEqual(model.selectedTheme.components.count, 7)
        XCTAssertEqual(model.notice?.title, "Opened a temporary sample")
        XCTAssertTrue(model.isDirty)
    }

    func testSetFrameCanBeUndone() {
        let model = makeModel(themes: [SampleTheme.make()])
        let component = model.orderedComponents[0]
        let original = component.frame
        var moved = original
        moved.x += 32
        model.select(component.id)
        model.setFrame(id: component.id, frame: moved)
        XCTAssertEqual(model.selectedComponent?.frame.x, original.x + 32)
        model.undo()
        XCTAssertEqual(model.selectedComponent?.frame.x, original.x)
    }

    private func makeModel(themes: [Theme]) -> EditorModel {
        EditorModel(store: InMemoryThemeStore(themes: themes))
    }
}

private final class RecordingDesktopIntegration: DesktopIntegrating {
    var appliedNames: [String] = []

    func apply(theme: Theme) -> DesktopApplyReport {
        appliedNames.append(theme.name)
        return UnavailableDesktopIntegration().apply(theme: theme)
    }
}

private final class FailingThemeStore: ThemeStoring {
    func loadLibrary() throws -> ThemeLibrary {
        throw ThemePersistenceError.directoryUnavailable("Disk offline.")
    }

    func save(_ theme: Theme) throws {}

    func delete(id: UUID) throws {}
}
