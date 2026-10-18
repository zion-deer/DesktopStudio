import Foundation

/// Layout math for the custom dock. Frames stay in canvas coordinates.
enum DockLayout {
    static let defaultIconSize = 48.0
    static let defaultSpacing = 8.0
    static let defaultPadding = 10.0
    static let iconSizeRange = 16.0...128.0
    static let spacingRange = 0.0...64.0
    static let paddingRange = 0.0...48.0

    static func contentSize(
        itemCount: Int,
        iconSize: Double,
        spacing: Double,
        padding: Double,
        edge: DockEdge
    ) -> (width: Double, height: Double) {
        let count = max(itemCount, 1)
        let along = padding * 2 + iconSize * Double(count) + spacing * Double(max(count - 1, 0))
        let across = iconSize + padding * 2
        if edge.isVertical {
            return (across, along)
        }
        return (along, across)
    }

    /// Pins the dock to a canvas edge. The other axis is left where the user placed it.
    /// The visible-frame mapping keeps this inside the area below the menu bar and beside the system Dock.
    static func snapped(_ frame: ComponentFrame, edge: DockEdge, canvas: CanvasSettings) -> ComponentFrame {
        var frame = frame.clamped(to: canvas)
        switch edge {
        case .top:
            frame.y = 0
        case .bottom:
            frame.y = max(canvas.height - frame.height, 0)
        case .left:
            frame.x = 0
        case .right:
            frame.x = max(canvas.width - frame.width, 0)
        }
        return frame.clamped(to: canvas)
    }

    /// Moves the dock along its edge to the leading, center, or trailing position.
    static func aligned(
        _ frame: ComponentFrame,
        alignment: DockAlignment,
        edge: DockEdge,
        canvas: CanvasSettings
    ) -> ComponentFrame {
        var frame = snapped(frame, edge: edge, canvas: canvas)
        switch edge {
        case .top, .bottom:
            switch alignment {
            case .leading:
                frame.x = 0
            case .center:
                frame.x = max((canvas.width - frame.width) / 2, 0)
            case .trailing:
                frame.x = max(canvas.width - frame.width, 0)
            }
        case .left, .right:
            switch alignment {
            case .leading:
                frame.y = 0
            case .center:
                frame.y = max((canvas.height - frame.height) / 2, 0)
            case .trailing:
                frame.y = max(canvas.height - frame.height, 0)
            }
        }
        return frame.clamped(to: canvas)
    }

    static func fittedFrame(_ frame: ComponentFrame, settings: ComponentSettings, canvas: CanvasSettings) -> ComponentFrame {
        let count = settings.dockItems.filter(\.pinned).count
        let size = contentSize(
            itemCount: count,
            iconSize: settings.dockIconSize,
            spacing: settings.dockSpacing,
            padding: settings.dockPadding,
            edge: settings.dockEdge
        )
        var fitted = frame
        fitted.width = size.width
        fitted.height = size.height
        return snapped(fitted, edge: settings.dockEdge, canvas: canvas)
    }
}

enum DockLaunchProblem: Equatable {
    case missingIdentifier
    case notInstalled

    var message: String {
        switch self {
        case .missingIdentifier:
            "This icon has no application to open. Choose an app in the editor."
        case .notInstalled:
            "That application is missing, was removed, or Launch Services cannot find it."
        }
    }
}

enum DockLaunch {
    static func problem(bundleIdentifier: String, isInstalled: Bool) -> DockLaunchProblem? {
        let identifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if identifier.isEmpty {
            return .missingIdentifier
        }
        if !isInstalled {
            return .notInstalled
        }
        return nil
    }
}
