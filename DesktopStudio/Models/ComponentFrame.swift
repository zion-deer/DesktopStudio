import Foundation

struct ComponentFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var zIndex: Int

    static let minimumLength: Double = 48

    func clamped(to canvas: CanvasSettings) -> ComponentFrame {
        var frame = self
        let maxWidth = max(canvas.width, Self.minimumLength)
        let maxHeight = max(canvas.height, Self.minimumLength)
        frame.width = min(max(frame.width, Self.minimumLength), maxWidth)
        frame.height = min(max(frame.height, Self.minimumLength), maxHeight)
        let maxX = max(canvas.width - frame.width, 0)
        let maxY = max(canvas.height - frame.height, 0)
        frame.x = min(max(frame.x, 0), maxX)
        frame.y = min(max(frame.y, 0), maxY)
        return frame
    }
}
