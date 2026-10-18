import CoreGraphics
import Foundation

/// A point in the saved theme. Units are the theme canvas, not the on-screen preview.
struct CanvasPoint: Equatable, Hashable {
    var x: Double
    var y: Double
}

/// A point in the on-screen preview after fit-to-view and editor zoom.
struct DisplayPoint: Equatable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

/// Converts between saved canvas coordinates and on-screen preview coordinates.
/// `zoom` changes only the preview. It is not part of the theme document.
struct CanvasLayout: Equatable {
    var fitScale: CGFloat
    var zoom: CGFloat
    var displaySize: CGSize

    /// On-screen points per canvas point. Includes both fitting and user zoom.
    var displayScale: CGFloat { fitScale * zoom }

    static func fit(canvas: CGSize, in available: CGSize, zoom: CGFloat = 1) -> CanvasLayout {
        let usableWidth = max(available.width - 64, 40)
        let usableHeight = max(available.height - 120, 40)
        let rawScale = min(
            usableWidth / max(canvas.width, 1),
            usableHeight / max(canvas.height, 1)
        )
        let fitScale: CGFloat = rawScale.isFinite && rawScale > 0 ? rawScale : 0.1
        let safeZoom: CGFloat = zoom.isFinite && zoom > 0 ? zoom : 1
        return CanvasLayout(
            fitScale: fitScale,
            zoom: safeZoom,
            displaySize: CGSize(width: canvas.width * fitScale * safeZoom, height: canvas.height * fitScale * safeZoom)
        )
    }

    func displayPoint(from canvas: CanvasPoint) -> DisplayPoint {
        DisplayPoint(x: canvas.x * displayScale, y: canvas.y * displayScale)
    }

    func canvasPoint(from display: DisplayPoint) -> CanvasPoint {
        CanvasPoint(
            x: Double(display.x / displayScale),
            y: Double(display.y / displayScale)
        )
    }

    func canvasTranslation(fromDisplay translation: CGSize) -> (x: Double, y: Double) {
        (
            Double(translation.width / displayScale),
            Double(translation.height / displayScale)
        )
    }

    func logicalPoint(fromDisplay point: CGPoint) -> CGPoint {
        let canvas = canvasPoint(from: DisplayPoint(x: point.x, y: point.y))
        return CGPoint(x: canvas.x, y: canvas.y)
    }

    func displayRect(for frame: ComponentFrame) -> CGRect {
        CGRect(
            x: frame.x * displayScale,
            y: frame.y * displayScale,
            width: frame.width * displayScale,
            height: frame.height * displayScale
        )
    }
}

enum EditorGeometry {
    static let grid: Double = 8

    static func snap(_ value: Double) -> Double {
        (value / grid).rounded() * grid
    }
}
