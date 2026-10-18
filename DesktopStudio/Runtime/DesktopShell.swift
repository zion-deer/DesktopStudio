import AppKit
import SwiftUI

/// Where a theme window sits relative to macOS chrome and other apps.
enum DesktopWindowLayer: Equatable {
    case aboveApplications
    case aboveSystemChrome

    var windowLevel: NSWindow.Level {
        switch self {
        case .aboveApplications:
            return .floating
        case .aboveSystemChrome:
            return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        }
    }
}

@MainActor
final class NoDesktopBackdrop: DesktopBackdropInstalling {
    private(set) var isCoveringTheScreen = false
    private(set) var isShown = false

    func show(theme: Theme, displays: [RuntimeDisplay]) {
        _ = theme
        if !isShown {
            isCoveringTheScreen = !displays.isEmpty
        }
        isShown = !displays.isEmpty
    }

    func revealApplications() {
        guard isShown else { return }
        isCoveringTheScreen = false
    }

    func hide() {
        isShown = false
        isCoveringTheScreen = false
    }
}

@MainActor
final class NoSystemChrome: SystemChromeHiding {
    private(set) var isHidden = false

    func hideChrome() {
        isHidden = true
    }

    func restoreChrome() {
        isHidden = false
    }
}

/// Hides the Dock and menu bar while Desktop Studio is the active app, then restores the previous options.
@MainActor
final class AppKitSystemChrome: SystemChromeHiding {
    private(set) var isHidden = false
    private var savedOptions: NSApplication.PresentationOptions?
    private var observer: NSObjectProtocol?

    func hideChrome() {
        if savedOptions == nil {
            savedOptions = NSApp.presentationOptions
        }
        isHidden = true
        applyHiddenOptions()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyHiddenOptions()
            }
        }
    }

    func restoreChrome() {
        isHidden = false
        if let savedOptions {
            NSApp.presentationOptions = savedOptions
        }
        savedOptions = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    private func applyHiddenOptions() {
        guard isHidden else { return }
        // hideMenuBar is only valid together with hideDock.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    }
}

/// One opaque window per display, painted with the theme background.
@MainActor
final class AppKitDesktopBackdrop: DesktopBackdropInstalling {
    private(set) var isCoveringTheScreen = false
    private var theme: Theme?
    private var displays: [RuntimeDisplay] = []
    private var windows: [NSWindow] = []

    func show(theme: Theme, displays: [RuntimeDisplay]) {
        let firstShow = windows.isEmpty
        self.theme = theme
        self.displays = displays
        if firstShow {
            isCoveringTheScreen = !displays.isEmpty
        }
        rebuild()
    }

    func revealApplications() {
        guard theme != nil else { return }
        isCoveringTheScreen = false
        rebuild()
    }

    func hide() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
        theme = nil
        displays = []
        isCoveringTheScreen = false
    }

    private func rebuild() {
        hideWindowsOnly()
        guard let theme else { return }
        for display in displays where display.frame.width > 1, display.frame.height > 1 {
            let window = NSWindow(
                contentRect: display.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.level = isCoveringTheScreen
                ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
                : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isMovable = false
            window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(
                srgbRed: theme.canvas.background.red,
                green: theme.canvas.background.green,
                blue: theme.canvas.background.blue,
                alpha: theme.canvas.background.opacity
            )
            let host = NSHostingView(rootView: DesktopBackdropView(canvas: theme.canvas))
            host.frame = NSRect(origin: .zero, size: display.frame.size)
            host.autoresizingMask = [.width, .height]
            window.contentView = host
            window.setFrame(display.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func hideWindowsOnly() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }
}

private struct DesktopBackdropView: View {
    var canvas: CanvasSettings

    var body: some View {
        Group {
            if canvas.style == .gradient {
                LinearGradient(
                    colors: [canvas.background.color, canvas.gradientEnd.color],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                canvas.background.color
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Theme desktop")
    }
}
