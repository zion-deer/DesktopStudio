import XCTest
@testable import DesktopStudio

final class ThemeCodingTests: XCTestCase {
    func testFactoryRoundTripsThroughJSON() throws {
        let theme = SampleTheme.make()
        let data = try ThemeCoding.encode(theme)
        let decoded = try ThemeCoding.decode(data, file: "memory.json").theme
        XCTAssertEqual(decoded, theme)
    }

    func testBundledSampleTheme() throws {
        let data = try ThemeResources.sampleThemeData()
        let theme = try ThemeCoding.decode(data, file: "SampleTheme.json").theme
        XCTAssertEqual(theme.name, "Night Harbor")
        XCTAssertEqual(theme.canvas.width, 1440)
        XCTAssertEqual(theme.canvas.height, 900)
        XCTAssertEqual(theme.canvas.style, .gradient)
        XCTAssertEqual(theme.components.count, 7)
        XCTAssertEqual(Set(theme.components.map(\.type)), Set(ComponentType.allCases))
    }

    func testBundledSampleMatchesFactory() throws {
        let data = try ThemeResources.sampleThemeData()
        let bundled = try ThemeCoding.decode(data, file: "SampleTheme.json").theme
        XCTAssertEqual(bundled, SampleTheme.make())
    }

    func testUnsupportedSchema() {
        let json = #"{"schemaVersion":2,"theme":{"name":"Future"}}"#
        XCTAssertThrowsError(try ThemeCoding.decode(Data(json.utf8), file: "Future.json")) { error in
            guard case ThemePersistenceError.unsupportedSchema(let file, let version) = error else {
                return XCTFail("Expected unsupported schema, got \(error)")
            }
            XCTAssertEqual(file, "Future.json")
            XCTAssertEqual(version, 2)
        }
    }

    func testUnknownComponentType() throws {
        let data = try ThemeCoding.encode(SampleTheme.make())
        let json = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"clock\"", with: "\"widget\"")
        XCTAssertThrowsError(try ThemeCoding.decode(Data(json.utf8), file: "Broken.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Unknown component type"))
        }
    }

    func testDuplicateComponentIDIsRejected() throws {
        var theme = SampleTheme.make()
        theme.components[1].id = theme.components[0].id
        let data = try ThemeCoding.encode(theme)
        XCTAssertThrowsError(try ThemeCoding.decode(data, file: "Dup.json")) { error in
            XCTAssertTrue(error.localizedDescription.contains("same id"))
        }
    }

    func testEmptyNameIsInvalid() {
        let theme = SampleTheme.blank(name: "   ")
        XCTAssertThrowsError(try theme.validate())
    }

    func testColorClampsAndNormalizesHex() {
        let color = ThemeColor(red: 2, green: -1, blue: 0.5, opacity: 4)
        XCTAssertEqual(color.red, 1)
        XCTAssertEqual(color.green, 0)
        XCTAssertEqual(color.blue, 0.5)
        XCTAssertEqual(color.opacity, 1)
        XCTAssertEqual(ThemeColor.normalize("#abc"), "#AABBCC")
        XCTAssertNil(ThemeColor.normalize("nope"))
        XCTAssertEqual(ThemeColor(hex: "#0E1424").hex, "#0E1424")
    }

    func testFrameClampsInsideTheDisplay() {
        let canvas = CanvasSettings(
            width: 1440,
            height: 900,
            style: .solid,
            background: ThemeColor(hex: "#000000"),
            gradientEnd: ThemeColor(hex: "#000000")
        )
        let frame = ComponentFrame(x: -40, y: 20, width: 10, height: 5000, zIndex: 3)
        let clamped = frame.clamped(to: canvas)
        XCTAssertEqual(clamped.x, 0)
        XCTAssertEqual(clamped.y, 0)
        XCTAssertEqual(clamped.width, ComponentFrame.minimumLength)
        XCTAssertEqual(clamped.height, 900)
        XCTAssertEqual(clamped.zIndex, 3)
    }

    func testSnapRoundsToTheLayoutGrid() {
        XCTAssertEqual(EditorGeometry.snap(13), 16)
        XCTAssertEqual(EditorGeometry.snap(10), 8)
        XCTAssertEqual(EditorGeometry.snap(8), 8)
    }
}
