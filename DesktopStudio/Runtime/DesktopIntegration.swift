import Foundation

/// Result of asking the desktop runtime to put a theme on screen.
/// `applied` is true only when macOS surfaces were actually changed.
struct DesktopApplyReport: Equatable {
    var applied: Bool
    var title: String
    var message: String
}

/// Boundary between saved themes and future macOS surfaces.
///
/// A later version can place non-activating panels, a custom dock window, and a launcher
/// behind this protocol. This build has no desktop windows, event taps, or menu-bar items.
protocol DesktopIntegrating {
    func apply(theme: Theme) -> DesktopApplyReport
}

struct UnavailableDesktopIntegration: DesktopIntegrating {
    func apply(theme: Theme) -> DesktopApplyReport {
        DesktopApplyReport(
            applied: false,
            title: "Nothing was applied",
            message: "“\(theme.name)” is still a preview. Desktop Studio does not place floating surfaces, replace the Dock, or install a launcher in this version."
        )
    }
}
