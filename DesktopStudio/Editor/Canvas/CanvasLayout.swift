import CoreGraphics
import Foundation

struct CanvasLayout: Equatable {
    var scale: CGFloat
    var displaySize: CGSize

    static func fit(canvas: CGSize, in available: CGSize) -> CanvasLayout {
        let usableWidth = max(available.width - 64, 40)
        let usableHeight = max(available.height - 88, 40)
        let rawScale = min(
            usableWidth / max(canvas.width, 1),
            usableHeight / max(canvas.height, 1)
        )
        let scale: CGFloat = rawScale.isFinite && rawScale > 0 ? rawScale : 0.1
        return CanvasLayout(
            scale: scale,
            displaySize: CGSize(width: canvas.width * scale, height: canvas.height * scale)
        )
    }

    func logicalPoint(fromDisplay point: CGPoint) -> CGPoint {
        CGPoint(x: point.x / scale, y: point.y / scale)
    }

    func displayRect(for frame: ComponentFrame) -> CGRect {
        CGRect(
            x: frame.x * scale,
            y: frame.y * scale,
            width: frame.width * scale,
            height: frame.height * scale
        )
    }
}

enum EditorGeometry {
    static let grid: Double = 8

    static func snap(_ value: Double) -> Double {
        (value / grid).rounded() * grid
    }
}
