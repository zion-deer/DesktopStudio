import Foundation

enum ResizeCorner: Equatable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var accessibilityLabel: String {
        switch self {
        case .topLeading: "Resize from top left"
        case .topTrailing: "Resize from top right"
        case .bottomLeading: "Resize from bottom left"
        case .bottomTrailing: "Resize from bottom right"
        }
    }
}

struct AlignmentGuide: Equatable, Identifiable {
    enum Axis: Equatable {
        case vertical
        case horizontal
    }

    var axis: Axis
    /// Position in canvas coordinates. A vertical guide is an x value; a horizontal guide is a y value.
    var canvasPosition: Double

    var id: String { "\(axis)-\(canvasPosition)" }
}

struct AlignmentResult: Equatable {
    var frame: ComponentFrame
    var guides: [AlignmentGuide]
}

/// Snaps a proposed canvas frame to the grid and to nearby component edges.
/// All positions are canvas coordinates. Callers convert pointer movement before calling in.
enum LayoutAlignment {
    static let threshold: Double = 6

    static func translated(
        origin: ComponentFrame,
        dx: Double,
        dy: Double,
        others: [ComponentFrame],
        canvas: CanvasSettings,
        snapToGrid: Bool,
        align: Bool
    ) -> AlignmentResult {
        var frame = origin
        frame.x += dx
        frame.y += dy
        if snapToGrid {
            frame.x = EditorGeometry.snap(frame.x)
            frame.y = EditorGeometry.snap(frame.y)
        }
        var guides: [AlignmentGuide] = []
        if align {
            if let snap = bestSnap(edges: horizontalEdges(of: frame), targets: xTargets(others: others, canvas: canvas)) {
                frame.x += snap.delta
                guides.append(AlignmentGuide(axis: .vertical, canvasPosition: snap.guide))
            }
            if let snap = bestSnap(edges: verticalEdges(of: frame), targets: yTargets(others: others, canvas: canvas)) {
                frame.y += snap.delta
                guides.append(AlignmentGuide(axis: .horizontal, canvasPosition: snap.guide))
            }
        }
        return finalize(frame, guides: guides, canvas: canvas)
    }

    static func resized(
        origin: ComponentFrame,
        corner: ResizeCorner,
        dx: Double,
        dy: Double,
        others: [ComponentFrame],
        canvas: CanvasSettings,
        snapToGrid: Bool,
        align: Bool
    ) -> AlignmentResult {
        var frame = origin
        let anchoredRight = origin.x + origin.width
        let anchoredBottom = origin.y + origin.height
        switch corner {
        case .bottomTrailing:
            frame.width = origin.width + dx
            frame.height = origin.height + dy
        case .bottomLeading:
            frame.x = origin.x + dx
            frame.width = anchoredRight - frame.x
            frame.height = origin.height + dy
        case .topTrailing:
            frame.y = origin.y + dy
            frame.height = anchoredBottom - frame.y
            frame.width = origin.width + dx
        case .topLeading:
            frame.x = origin.x + dx
            frame.width = anchoredRight - frame.x
            frame.y = origin.y + dy
            frame.height = anchoredBottom - frame.y
        }

        if snapToGrid {
            switch corner {
            case .bottomTrailing:
                frame.width = max(EditorGeometry.snap(frame.width), ComponentFrame.minimumLength)
                frame.height = max(EditorGeometry.snap(frame.height), ComponentFrame.minimumLength)
            case .bottomLeading:
                frame.x = EditorGeometry.snap(frame.x)
                frame.width = anchoredRight - frame.x
                frame.height = max(EditorGeometry.snap(frame.height), ComponentFrame.minimumLength)
            case .topTrailing:
                frame.y = EditorGeometry.snap(frame.y)
                frame.height = anchoredBottom - frame.y
                frame.width = max(EditorGeometry.snap(frame.width), ComponentFrame.minimumLength)
            case .topLeading:
                frame.x = EditorGeometry.snap(frame.x)
                frame.width = anchoredRight - frame.x
                frame.y = EditorGeometry.snap(frame.y)
                frame.height = anchoredBottom - frame.y
            }
        }

        var guides: [AlignmentGuide] = []
        if align {
            switch corner {
            case .bottomTrailing, .topTrailing:
                if let snap = bestSnap(edges: [frame.x + frame.width], targets: xTargets(others: others, canvas: canvas)) {
                    frame.width += snap.delta
                    guides.append(AlignmentGuide(axis: .vertical, canvasPosition: snap.guide))
                }
            case .bottomLeading, .topLeading:
                if let snap = bestSnap(edges: [frame.x], targets: xTargets(others: others, canvas: canvas)) {
                    let right = frame.x + frame.width
                    frame.x += snap.delta
                    frame.width = right - frame.x
                    guides.append(AlignmentGuide(axis: .vertical, canvasPosition: snap.guide))
                }
            }
            switch corner {
            case .bottomTrailing, .bottomLeading:
                if let snap = bestSnap(edges: [frame.y + frame.height], targets: yTargets(others: others, canvas: canvas)) {
                    frame.height += snap.delta
                    guides.append(AlignmentGuide(axis: .horizontal, canvasPosition: snap.guide))
                }
            case .topTrailing, .topLeading:
                if let snap = bestSnap(edges: [frame.y], targets: yTargets(others: others, canvas: canvas)) {
                    let bottom = frame.y + frame.height
                    frame.y += snap.delta
                    frame.height = bottom - frame.y
                    guides.append(AlignmentGuide(axis: .horizontal, canvasPosition: snap.guide))
                }
            }
        }

        preserveAnchor(&frame, corner: corner, anchoredRight: anchoredRight, anchoredBottom: anchoredBottom)
        return finalize(frame, guides: guides, canvas: canvas)
    }

    private static func preserveAnchor(
        _ frame: inout ComponentFrame,
        corner: ResizeCorner,
        anchoredRight: Double,
        anchoredBottom: Double
    ) {
        let minimum = ComponentFrame.minimumLength
        switch corner {
        case .bottomTrailing:
            frame.width = max(frame.width, minimum)
            frame.height = max(frame.height, minimum)
        case .bottomLeading:
            frame.width = max(frame.width, minimum)
            frame.x = anchoredRight - frame.width
            frame.height = max(frame.height, minimum)
        case .topTrailing:
            frame.width = max(frame.width, minimum)
            frame.height = max(frame.height, minimum)
            frame.y = anchoredBottom - frame.height
        case .topLeading:
            frame.width = max(frame.width, minimum)
            frame.x = anchoredRight - frame.width
            frame.height = max(frame.height, minimum)
            frame.y = anchoredBottom - frame.height
        }
    }

    private static func finalize(_ frame: ComponentFrame, guides: [AlignmentGuide], canvas: CanvasSettings) -> AlignmentResult {
        let clamped = frame.clamped(to: canvas)
        let kept = guides.filter { guide in
            switch guide.axis {
            case .vertical:
                return aligned(horizontalEdges(of: clamped), to: guide.canvasPosition)
            case .horizontal:
                return aligned(verticalEdges(of: clamped), to: guide.canvasPosition)
            }
        }
        return AlignmentResult(frame: clamped, guides: kept)
    }

    private static func horizontalEdges(of frame: ComponentFrame) -> [Double] {
        [frame.x, frame.x + frame.width / 2, frame.x + frame.width]
    }

    private static func verticalEdges(of frame: ComponentFrame) -> [Double] {
        [frame.y, frame.y + frame.height / 2, frame.y + frame.height]
    }

    private static func xTargets(others: [ComponentFrame], canvas: CanvasSettings) -> [Double] {
        var targets = [0, canvas.width / 2, canvas.width]
        for frame in others {
            targets.append(contentsOf: horizontalEdges(of: frame))
        }
        return targets
    }

    private static func yTargets(others: [ComponentFrame], canvas: CanvasSettings) -> [Double] {
        var targets = [0, canvas.height / 2, canvas.height]
        for frame in others {
            targets.append(contentsOf: verticalEdges(of: frame))
        }
        return targets
    }

    private static func bestSnap(edges: [Double], targets: [Double]) -> (delta: Double, guide: Double)? {
        var best: (distance: Double, delta: Double, guide: Double)?
        for edge in edges {
            for target in targets {
                let distance = abs(edge - target)
                guard distance <= threshold else { continue }
                if best == nil || distance < best!.distance {
                    best = (distance, target - edge, target)
                }
            }
        }
        guard let best else { return nil }
        return (best.delta, best.guide)
    }

    private static func aligned(_ edges: [Double], to guide: Double) -> Bool {
        edges.contains { abs($0 - guide) < 0.5 }
    }
}
