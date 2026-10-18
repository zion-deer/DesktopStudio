import AppKit
import Foundation
import ServiceManagement

/// Registers Desktop Studio itself as a login item. It never changes the system Dock.
protocol LoginItemRegistering: AnyObject {
    func apply(enabled: Bool) -> String?
}

/// Used by tests and by any runtime that should not touch login items.
final class DisabledLoginItems: LoginItemRegistering {
    func apply(enabled: Bool) -> String? { nil }
}

final class SystemLoginItemRegistration: LoginItemRegistering {
    func apply(enabled: Bool) -> String? {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled:
                return nil
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
                return "macOS needs approval in System Settings → General → Login Items before Desktop Studio can open at login."
            case .notRegistered, .notFound:
                do {
                    try service.register()
                } catch {
                    return error.localizedDescription
                }
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                    return "Approve Desktop Studio in System Settings → General → Login Items. The system Dock is unchanged."
                }
                return nil
            @unknown default:
                return "Login items are not available on this Mac."
            }
        }
        if service.status == .notRegistered || service.status == .notFound {
            return nil
        }
        do {
            try service.unregister()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

protocol ApplicationLaunching: AnyObject {
    func applicationURL(bundleIdentifier: String) -> URL?
    func openApplication(at url: URL, completion: @escaping (String?) -> Void)
}

final class WorkspaceApplicationLauncher: ApplicationLaunching {
    func applicationURL(bundleIdentifier: String) -> URL? {
        let identifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
    }

    func openApplication(at url: URL, completion: @escaping (String?) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            completion(error?.localizedDescription)
        }
    }
}
