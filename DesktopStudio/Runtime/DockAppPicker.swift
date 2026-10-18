import AppKit
import Foundation
import UniformTypeIdentifiers

/// Result of choosing an application for the custom dock. The file URL is not kept.
struct PickedDockApp: Equatable {
    var title: String
    var bundleIdentifier: String
}

@MainActor
enum DockAppPicker {
    /// Presents the system open panel for application bundles.
    static func chooseApplication() -> PickedDockApp? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.title = "Add Application"
        panel.prompt = "Add"
        panel.message = "Choose an application to pin. Desktop Studio stores its bundle identifier, not a file path."
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return identify(url)
    }

    static func identify(_ url: URL) -> PickedDockApp? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier, !identifier.isEmpty else {
            return nil
        }
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let title = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent
        return PickedDockApp(title: title, bundleIdentifier: identifier)
    }
}
