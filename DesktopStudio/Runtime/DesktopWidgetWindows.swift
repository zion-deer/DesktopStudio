import AppKit
import SwiftUI

@MainActor
final class AppKitDesktopSurfaceFactory: DesktopSurfaceInstalling {
    func install(
        component: DesktopComponent,
        theme: Theme,
        windowFrame: CGRect,
        controller: DesktopRuntimeController
    ) -> DesktopWidgetSurface {
        AppKitWidgetSurface(component: component, theme: theme, windowFrame: windowFrame, controller: controller)
    }
}

@MainActor
final class AppKitWidgetSurface: NSObject, DesktopWidgetSurface, NSWindowDelegate {
    let componentID: UUID
    private let panel: WidgetPanel
    private let model: WidgetModel
    private weak var controller: DesktopRuntimeController?
    private var isAdjustingFrame = false
    private var moveWork: DispatchWorkItem?

    init(component: DesktopComponent, theme: Theme, windowFrame: CGRect, controller: DesktopRuntimeController) {
        self.componentID = component.id
        self.controller = controller
        self.model = WidgetModel(component: component, theme: theme)
        self.panel = WidgetPanel(contentRect: windowFrame)
        super.init()
        let root = DesktopWidgetView(
            model: model,
            onCommit: { [weak controller] settings in
                controller?.updateSettings(componentID: component.id, settings: settings)
            },
            onOpenApp: { [weak controller] bundleIdentifier in
                controller?.launchApplication(bundleIdentifier: bundleIdentifier, componentID: component.id)
            },
            onOpenLauncher: { [weak controller] in
                controller?.toggleLauncher()
            },
            onDismissLauncher: { [weak controller] in
                controller?.hideLauncher()
            },
            onStop: { [weak controller] in
                _ = controller?.stopExperience()
            }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        panel.delegate = self
        panel.onMouseUp = { [weak self] in
            self?.scheduleMoveCommit()
        }
        if component.type == .launcher {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func place(windowFrame: CGRect) {
        guard !panel.frame.equalTo(windowFrame) else { return }
        isAdjustingFrame = true
        panel.setFrame(windowFrame, display: true)
        isAdjustingFrame = false
    }

    func update(component: DesktopComponent, theme: Theme) {
        model.component = component
        model.theme = theme
    }

    func orderFront() {
        panel.orderFrontRegardless()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    func setStatus(_ message: String?) {
        model.status = message
    }

    func setLayer(_ layer: DesktopWindowLayer) {
        if layer == .aboveApplications, model.component.type == .dock {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        } else {
            panel.level = layer.windowLevel
        }
    }

    func setLauncherShown(_ shown: Bool) {
        guard model.component.type == .launcher else { return }
        if shown {
            panel.makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .desktopLauncherDidOpen, object: model.component.id.uuidString)
        } else {
            panel.orderOut(nil)
        }
    }

    func close() {
        moveWork?.cancel()
        panel.delegate = nil
        panel.close()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isAdjustingFrame else { return }
        scheduleMoveCommit()
    }

    private func scheduleMoveCommit() {
        moveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.controller?.widgetDidEndMove(componentID: self.componentID, windowFrame: self.panel.frame)
        }
        moveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}

private final class WidgetPanel: NSPanel {
    var onMouseUp: (() -> Void)?

    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = DesktopWindowLayer.aboveSystemChrome.windowLevel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        onMouseUp?()
    }
}
