import CoreGraphics
import Foundation

/// One connected display, in AppKit global coordinates (origin at the bottom left).
struct RuntimeDisplay: Equatable, Identifiable {
    var id: UInt32
    var frame: CGRect
    var visibleFrame: CGRect
    var isMain: Bool
}

/// Which part of a display the theme covers.
enum CanvasPlacementArea: Equatable {
    /// The area beside the menu bar and system Dock.
    case visibleFrame
    /// The whole display, including the menu bar and Dock strips.
    case fullFrame
}

/// Where a theme canvas is drawn inside one display.
struct FittedCanvas: Equatable {
    var displayID: UInt32
    var scale: Double
    var rect: CGRect
}

/// Converts theme canvas coordinates (top-left origin) to AppKit window frames.
enum CanvasScreenMapping {
    /// Aspect-fits the canvas inside the chosen display area and centers it.
    static func fit(
        canvasWidth: Double,
        canvasHeight: Double,
        display: RuntimeDisplay,
        area: CanvasPlacementArea = .visibleFrame
    ) -> FittedCanvas? {
        let visible = area == .fullFrame ? display.frame : display.visibleFrame
        guard canvasWidth > 0, canvasHeight > 0, visible.width > 1, visible.height > 1 else { return nil }
        let scale = min(visible.width / canvasWidth, visible.height / canvasHeight)
        guard scale.isFinite, scale > 0 else { return nil }
        let width = canvasWidth * scale
        let height = canvasHeight * scale
        let rect = CGRect(
            x: visible.midX - width / 2,
            y: visible.midY - height / 2,
            width: width,
            height: height
        )
        return FittedCanvas(displayID: display.id, scale: scale, rect: rect)
    }

    static func windowFrame(component: ComponentFrame, fitted: FittedCanvas) -> CGRect {
        let scale = fitted.scale
        let width = component.width * scale
        let height = component.height * scale
        let x = fitted.rect.minX + component.x * scale
        let y = fitted.rect.maxY - (component.y * scale) - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Canvas position of a window's top-left corner. Width and height stay on the saved component.
    static func canvasPosition(windowFrame: CGRect, fitted: FittedCanvas) -> (x: Double, y: Double) {
        let scale = max(fitted.scale, 0.000_1)
        let x = (windowFrame.minX - fitted.rect.minX) / scale
        let y = (fitted.rect.maxY - windowFrame.maxY) / scale
        return (x, y)
    }

    static func display(containing point: CGPoint, displays: [RuntimeDisplay]) -> RuntimeDisplay? {
        if let match = displays.first(where: { $0.frame.insetBy(dx: -0.5, dy: -0.5).contains(point) }) {
            return match
        }
        return displays.first(where: \.isMain) ?? displays.first
    }
}

/// Clock strings used by the desktop clock widget. Formatting is locale-aware and has no window dependency.
enum DesktopClockText {
    static func timeString(
        date: Date,
        settings: ComponentSettings,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch settings.timeFormat {
        case .system:
            formatter.timeStyle = settings.showsSeconds ? .medium : .short
            formatter.dateStyle = .none
        case .twelveHour:
            formatter.dateFormat = settings.showsSeconds ? "h:mm:ss a" : "h:mm a"
        case .twentyFourHour:
            formatter.dateFormat = settings.showsSeconds ? "HH:mm:ss" : "HH:mm"
        }
        return formatter.string(from: date)
    }

    static func dateString(
        date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
