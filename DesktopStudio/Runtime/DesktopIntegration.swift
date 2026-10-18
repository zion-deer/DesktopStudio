import Foundation

/// Result of asking the desktop runtime to show or hide theme windows.
///
/// `applied` is true only when this app opened or closed its own widget windows.
/// It does not mean the Dock, menu bar, Finder, wallpaper, or system files changed.
struct DesktopApplyReport: Equatable {
    var applied: Bool
    var title: String
    var message: String
}

/// Boundary between saved themes and macOS windows owned by Desktop Studio.
@MainActor
protocol DesktopIntegrating {
    func apply(theme: Theme) -> DesktopApplyReport
    func stopExperience() -> DesktopApplyReport
    func restoreDefaultExperience() -> DesktopApplyReport
    /// Reopens widget windows after a relaunch when a session is still marked active.
    /// Returns nil when there is nothing to restore. A failure report leaves the editor usable.
    func recoverPersistedExperience() -> DesktopApplyReport?
    func toggleLauncher()
    var isExperienceActive: Bool { get }
}

extension DesktopIntegrating {
    func stopExperience() -> DesktopApplyReport {
        DesktopApplyReport(
            applied: false,
            title: "Desktop experience is stopped",
            message: "This runtime has no Desktop Studio windows to close."
        )
    }

    func restoreDefaultExperience() -> DesktopApplyReport {
        DesktopApplyReport(
            applied: false,
            title: "Desktop is already the default",
            message: "This runtime does not change the Dock, menu bar, Finder, wallpaper, or system files."
        )
    }

    func recoverPersistedExperience() -> DesktopApplyReport? { nil }

    func toggleLauncher() {}

    var isExperienceActive: Bool { false }
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
