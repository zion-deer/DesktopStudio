import CoreGraphics
import XCTest
@testable import DesktopStudio

final class LayoutGeometryTests: XCTestCase {
    func testZoomChangesPreviewScaleWithoutChangingCanvasPoints() {
        let canvas = CGSize(width: 1440, height: 900)
        let available = CGSize(width: 900, height: 700)
        let fitted = CanvasLayout.fit(canvas: canvas, in: available, zoom: 1)
        let zoomed = CanvasLayout.fit(canvas: canvas, in: available, zoom: 2)

        XCTAssertEqual(zoomed.fitScale, fitted.fitScale, accuracy: 0.000_1)
        XCTAssertEqual(zoomed.displaySize.width, fitted.displaySize.width * 2, accuracy: 0.01)
        XCTAssertEqual(zoomed.displayScale, fitted.displayScale * 2, accuracy: 0.000_1)

        let canvasPoint = CanvasPoint(x: 120, y: 48)
        let display = zoomed.displayPoint(from: canvasPoint)
        let roundTrip = zoomed.canvasPoint(from: display)
        XCTAssertEqual(roundTrip.x, canvasPoint.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, canvasPoint.y, accuracy: 0.001)
    }

    func testDisplayTranslationConvertsBackToCanvasUnits() {
        let layout = CanvasLayout.fit(canvas: CGSize(width: 1000, height: 500), in: CGSize(width: 500, height: 400), zoom: 2)
        let translation = layout.canvasTranslation(fromDisplay: CGSize(width: layout.displayScale * 16, height: layout.displayScale * -8))
        XCTAssertEqual(translation.x, 16, accuracy: 0.001)
        XCTAssertEqual(translation.y, -8, accuracy: 0.001)
    }

    func testMoveSnapsToANeighborEdgeAndReportsAGuide() {
        let canvas = sampleCanvas()
        let origin = ComponentFrame(x: 40, y: 80, width: 100, height: 60, zIndex: 1)
        let neighbor = ComponentFrame(x: 200, y: 80, width: 80, height: 60, zIndex: 0)
        let result = LayoutAlignment.translated(
            origin: origin,
            dx: 57,
            dy: 0,
            others: [neighbor],
            canvas: canvas,
            snapToGrid: true,
            align: true
        )
        XCTAssertEqual(result.frame.x + result.frame.width, neighbor.x, accuracy: 0.001)
        XCTAssertTrue(result.guides.contains { $0.axis == .vertical && abs($0.canvasPosition - neighbor.x) < 0.001 })
    }

    func testMoveWithoutAlignmentUsesTheGrid() {
        let canvas = sampleCanvas()
        let origin = ComponentFrame(x: 10, y: 10, width: 80, height: 40, zIndex: 0)
        let result = LayoutAlignment.translated(
            origin: origin,
            dx: 3,
            dy: 5,
            others: [],
            canvas: canvas,
            snapToGrid: true,
            align: false
        )
        XCTAssertEqual(result.frame.x, 16)
        XCTAssertEqual(result.frame.y, 16)
        XCTAssertTrue(result.guides.isEmpty)
    }

    func testFreeMoveKeepsTheExactCanvasPosition() {
        let canvas = sampleCanvas()
        let origin = ComponentFrame(x: 10, y: 12, width: 80, height: 40, zIndex: 0)
        let result = LayoutAlignment.translated(
            origin: origin,
            dx: 3.5,
            dy: 1.25,
            others: [],
            canvas: canvas,
            snapToGrid: false,
            align: false
        )
        XCTAssertEqual(result.frame.x, 13.5, accuracy: 0.001)
        XCTAssertEqual(result.frame.y, 13.25, accuracy: 0.001)
    }

    func testResizeFromBottomTrailingSnapsTheRightEdge() {
        let canvas = sampleCanvas()
        let origin = ComponentFrame(x: 20, y: 20, width: 100, height: 80, zIndex: 0)
        let neighbor = ComponentFrame(x: 150, y: 200, width: 40, height: 40, zIndex: 1)
        let result = LayoutAlignment.resized(
            origin: origin,
            corner: .bottomTrailing,
            dx: 26,
            dy: 4,
            others: [neighbor],
            canvas: canvas,
            snapToGrid: true,
            align: true
        )
        XCTAssertEqual(result.frame.x, origin.x, accuracy: 0.001)
        XCTAssertEqual(result.frame.x + result.frame.width, neighbor.x, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(result.frame.height, ComponentFrame.minimumLength)
    }

    func testResizeFromTopLeadingKeepsTheBottomRightAnchored() {
        let canvas = sampleCanvas()
        let origin = ComponentFrame(x: 100, y: 100, width: 160, height: 120, zIndex: 0)
        let result = LayoutAlignment.resized(
            origin: origin,
            corner: .topLeading,
            dx: 20,
            dy: 16,
            others: [],
            canvas: canvas,
            snapToGrid: false,
            align: false
        )
        XCTAssertEqual(result.frame.x + result.frame.width, origin.x + origin.width, accuracy: 0.001)
        XCTAssertEqual(result.frame.y + result.frame.height, origin.y + origin.height, accuracy: 0.001)
        XCTAssertEqual(result.frame.x, 120, accuracy: 0.001)
        XCTAssertEqual(result.frame.y, 116, accuracy: 0.001)
    }

    private func sampleCanvas() -> CanvasSettings {
        CanvasSettings(
            width: 1440,
            height: 900,
            style: .solid,
            background: ThemeColor(hex: "#10141C"),
            gradientEnd: ThemeColor(hex: "#10141C")
        )
    }
}
