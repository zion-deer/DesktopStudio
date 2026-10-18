import AppKit
import Foundation

/// Receives theme edits that originated from a desktop widget.
@MainActor
protocol RuntimeLayoutSink: AnyObject {
    func runtimeDidUpdateComponent(
        themeID: UUID,
        componentID: UUID,
        frame: ComponentFrame?,
        settings: ComponentSettings?
    ) -> Bool

    func runtimeDidReplaceTheme(_ theme: Theme) -> Bool
}

@MainActor
protocol ScreenProviding: AnyObject {
    func screens() -> [RuntimeDisplay]
}

@MainActor
protocol DesktopWidgetSurface: AnyObject {
    var componentID: UUID { get }
    func place(windowFrame: CGRect)
    func update(component: DesktopComponent, theme: Theme)
    func orderFront()
    func setVisible(_ visible: Bool)
    func setStatus(_ message: String?)
    func setLauncherShown(_ shown: Bool)
    func setLayer(_ layer: DesktopWindowLayer)
    func close()
}

extension DesktopWidgetSurface {
    func setLayer(_ layer: DesktopWindowLayer) {}
}

/// Covers the wallpaper and desktop icons, and can also cover the Dock and menu bar.
@MainActor
protocol DesktopBackdropInstalling: AnyObject {
    func show(theme: Theme, displays: [RuntimeDisplay])
    func revealApplications()
    func hide()
    var isCoveringTheScreen: Bool { get }
}

/// Hides the Dock and menu bar while a theme is the desktop, then restores them.
@MainActor
protocol SystemChromeHiding: AnyObject {
    func hideChrome()
    func restoreChrome()
    var isHidden: Bool { get }
}

@MainActor
protocol DesktopSurfaceInstalling: AnyObject {
    func install(
        component: DesktopComponent,
        theme: Theme,
        windowFrame: CGRect,
        controller: DesktopRuntimeController
    ) -> DesktopWidgetSurface
}

/// Loads a validated theme and shows clock, text, notes, app-shortcut, and custom dock windows.
///
/// Apply covers the desktop with the theme and hides the Dock and menu bar.
/// Stop closes those windows and puts the system chrome back.
@MainActor
final class DesktopRuntimeController: DesktopIntegrating {
    static let supportedTypes: Set<ComponentType> = [.clock, .text, .notes, .appShortcut, .dock, .launcher]

    private let themeStore: (any ThemeStoring)?
    private let sessionStore: any RuntimeSessionStoring
    private let screens: any ScreenProviding
    private let surfaces: any DesktopSurfaceInstalling
    private let loginItems: any LoginItemRegistering
    private let appLauncher: any ApplicationLaunching
    private let backdrop: any DesktopBackdropInstalling
    private let chrome: any SystemChromeHiding
    weak var layoutSink: RuntimeLayoutSink?

    private var session: DesktopExperienceSession?
    private var appliedTheme: Theme?
    private var surfaceByID: [UUID: any DesktopWidgetSurface] = [:]
    private var observers: [NSObjectProtocol] = []
    private let hotkey = LauncherHotkey()
    private var launcherShown = false

    var isExperienceActive: Bool { session?.active == true }

    init(
        themeStore: (any ThemeStoring)?,
        sessionStore: any RuntimeSessionStoring,
        screens: any ScreenProviding,
        surfaces: any DesktopSurfaceInstalling,
        loginItems: any LoginItemRegistering = DisabledLoginItems(),
        appLauncher: any ApplicationLaunching = WorkspaceApplicationLauncher(),
        backdrop: any DesktopBackdropInstalling = NoDesktopBackdrop(),
        chrome: any SystemChromeHiding = NoSystemChrome()
    ) {
        self.themeStore = themeStore
        self.sessionStore = sessionStore
        self.screens = screens
        self.surfaces = surfaces
        self.loginItems = loginItems
        self.appLauncher = appLauncher
        self.backdrop = backdrop
        self.chrome = chrome
        self.session = sessionStore.load()
    }

    static func makeForApplication(themeStore: any ThemeStoring) -> DesktopRuntimeController {
        let sessions: any RuntimeSessionStoring
        if let url = try? RuntimeSessionLocation.defaultFileURL() {
            sessions = FileRuntimeSessionStore(fileURL: url)
        } else {
            StudioLog.runtime.error("Runtime session folder is unavailable. Desktop windows will not be restored after restart.")
            sessions = MemoryRuntimeSessionStore()
        }
        let controller = DesktopRuntimeController(
            themeStore: themeStore,
            sessionStore: sessions,
            screens: AppKitScreenProvider(),
            surfaces: AppKitDesktopSurfaceFactory(),
            loginItems: SystemLoginItemRegistration(),
            appLauncher: WorkspaceApplicationLauncher(),
            backdrop: AppKitDesktopBackdrop(),
            chrome: AppKitSystemChrome()
        )
        controller.installSystemObservers()
        return controller
    }

    func installSystemObservers() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleScreenChange()
            }
        })
    }

    func apply(theme: Theme) -> DesktopApplyReport {
        do {
            try theme.validate()
        } catch {
            return DesktopApplyReport(
                applied: false,
                title: "Theme was not applied",
                message: "\(error.localizedDescription) The editor is still open, and any desktop windows already showing were left as they were."
            )
        }

        let supported = theme.components.filter { Self.supportedTypes.contains($0.type) }
        guard !supported.isEmpty else {
            return DesktopApplyReport(
                applied: false,
                title: "Theme was not applied",
                message: "“\(theme.name)” has no clock, text, notes, app shortcut, dock, or launcher to show."
            )
        }

        guard let main = preferredDisplay(in: screens.screens()) else {
            return DesktopApplyReport(
                applied: false,
                title: "Theme was not applied",
                message: "No display is available. The editor is still open."
            )
        }

        let prepared = prepareDocks(in: theme)
        let placements = prepared.components.filter { Self.supportedTypes.contains($0.type) }.map { component in
            RuntimePlacementRecord(
                componentID: component.id,
                displayID: main.id,
                frame: component.frame.clamped(to: prepared.canvas)
            )
        }
        return present(
            theme: prepared,
            baseline: prepared,
            placements: placements,
            title: "Desktop experience is on"
        )
    }

    func stopExperience() -> DesktopApplyReport {
        guard var session, session.active else {
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience is stopped",
                message: "No Desktop Studio windows are open. The Dock and menu bar are visible."
            )
        }
        closeSurfaces()
        dismissShell()
        session.active = false
        self.session = session
        appliedTheme = nil
        sessionStore.save(session)
        return DesktopApplyReport(
            applied: true,
            title: "Desktop experience stopped",
            message: "The theme was closed and the Dock and menu bar are visible again. Positions already saved in the theme were kept."
        )
    }

    func restoreDefaultExperience() -> DesktopApplyReport {
        guard let session else {
            closeSurfaces()
            dismissShell()
            appliedTheme = nil
            return DesktopApplyReport(
                applied: false,
                title: "Desktop is already the default",
                message: "No Desktop Studio windows are open. This app does not replace the Dock, menu bar, Finder, or system files, so there is nothing else to put back."
            )
        }
        let baseline = session.baseline
        closeSurfaces()
        dismissShell()
        appliedTheme = nil
        self.session = nil
        sessionStore.clear()
        let saved = replaceSavedTheme(baseline)
        hotkey.uninstall()
        launcherShown = false
        _ = loginItems.apply(enabled: baseline.components.contains { $0.type == .dock && $0.settings.launchAtLogin })
        let saveNote = saved
            ? "Widget positions and text were returned to the theme as it was when you chose Apply."
            : "Widget windows were closed, but the theme file could not be updated. Reopen the theme from the editor if it looks out of date."
        return DesktopApplyReport(
            applied: true,
            title: "Default desktop restored",
            message: "\(saveNote) The Dock and menu bar are visible again."
        )
    }

    func recoverPersistedExperience() -> DesktopApplyReport? {
        guard let stored = sessionStore.load() ?? session, stored.active else { return nil }
        session = stored

        guard let themeStore else {
            deactivatePersistedSession()
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience was not restored",
                message: "Theme storage is unavailable. The editor is open, and no widget windows were created."
            )
        }

        let library: ThemeLibrary
        do {
            library = try themeStore.loadLibrary()
        } catch {
            deactivatePersistedSession()
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience was not restored",
                message: "\(error.localizedDescription) The editor is open."
            )
        }

        guard let theme = library.themes.first(where: { $0.id == stored.themeID }) else {
            deactivatePersistedSession()
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience was not restored",
                message: "The applied theme is no longer in the library. The editor is open, and no widget windows were created."
            )
        }

        do {
            try theme.validate()
        } catch {
            deactivatePersistedSession()
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience was not restored",
                message: "\(error.localizedDescription) The editor is open, and the invalid theme was not shown."
            )
        }

        let supportedIDs = Set(theme.components.filter { Self.supportedTypes.contains($0.type) }.map(\.id))
        guard !supportedIDs.isEmpty else {
            deactivatePersistedSession()
            return DesktopApplyReport(
                applied: false,
                title: "Desktop experience was not restored",
                message: "“\(theme.name)” no longer has a clock, text, notes, app shortcut, dock, or launcher to show."
            )
        }

        let placements = theme.components.compactMap { component -> RuntimePlacementRecord? in
            guard supportedIDs.contains(component.id) else { return nil }
            let displayID = stored.placements.first(where: { $0.componentID == component.id })?.displayID
            return RuntimePlacementRecord(
                componentID: component.id,
                displayID: displayID ?? 0,
                frame: component.frame
            )
        }
        return present(
            theme: theme,
            baseline: stored.baseline,
            placements: placements,
            title: "Desktop experience restored"
        )
    }

    func relinquishWindows() {
        closeSurfaces()
    }

    func handleWake() {
        guard session?.active == true else { return }
        if surfaceByID.isEmpty, let theme = appliedTheme {
            _ = present(
                theme: theme,
                baseline: session?.baseline ?? theme,
                placements: session?.placements ?? [],
                title: "Desktop experience restored"
            )
        } else {
            handleScreenChange()
        }
    }

    func handleScreenChange() {
        guard var session, session.active, let theme = appliedTheme else { return }
        let displays = screens.screens()
        guard !displays.isEmpty else {
            for surface in surfaceByID.values {
                surface.setVisible(false)
            }
            return
        }
        let fallback = preferredDisplay(in: displays)
        for index in session.placements.indices {
            var placement = session.placements[index]
            let display = displays.first(where: { $0.id == placement.displayID }) ?? fallback
            guard let display else { continue }
            if placement.displayID != display.id {
                placement.displayID = display.id
            }
            guard let component = theme.components.first(where: { $0.id == placement.componentID }),
                  let fitted = fittedCanvas(theme, on: display)
            else { continue }
            placement.frame = component.frame
            session.placements[index] = placement
            surfaceByID[component.id]?.setVisible(true)
            surfaceByID[component.id]?.place(windowFrame: CanvasScreenMapping.windowFrame(component: component.frame, fitted: fitted))
        }
        self.session = session
        sessionStore.save(session)
        backdrop.show(theme: theme, displays: displays)
        orderSurfaces(for: theme)
    }

    func widgetDidEndMove(componentID: UUID, windowFrame: CGRect) {
        guard var theme = appliedTheme, var session else { return }
        guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
        let displays = screens.screens()
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard let display = CanvasScreenMapping.display(containing: center, displays: displays),
              let fitted = fittedCanvas(theme, on: display)
        else { return }

        let position = CanvasScreenMapping.canvasPosition(windowFrame: windowFrame, fitted: fitted)
        var frame = theme.components[index].frame
        frame.x = position.x
        frame.y = position.y
        frame = frame.clamped(to: theme.canvas)
        if theme.components[index].type == .dock {
            frame = DockLayout.snapped(frame, edge: theme.components[index].settings.dockEdge, canvas: theme.canvas)
        }
        let previous = theme.components[index].frame
        let previousDisplay = session.placements.first(where: { $0.componentID == componentID })?.displayID
        guard !framesMatch(previous, frame) || previousDisplay != display.id else { return }

        theme.components[index].frame = frame
        theme.updatedAt = Date()
        if let placementIndex = session.placements.firstIndex(where: { $0.componentID == componentID }) {
            session.placements[placementIndex].displayID = display.id
            session.placements[placementIndex].frame = frame
        }
        guard commit(theme, componentID: componentID) else {
            theme.components[index].frame = previous
            return
        }
        appliedTheme = theme
        self.session = session
        sessionStore.save(session)
        if let refitted = fittedCanvas(theme, on: display) {
            surfaceByID[componentID]?.place(
                windowFrame: CanvasScreenMapping.windowFrame(component: frame, fitted: refitted)
            )
        }
    }

    func updateSettings(componentID: UUID, settings: ComponentSettings) {
        guard var theme = appliedTheme else { return }
        guard let index = theme.components.firstIndex(where: { $0.id == componentID }) else { return }
        let previous = theme.components[index].settings
        var next = settings
        if next.title.count > ThemeLimits.maxNameLength {
            next.title = String(next.title.prefix(ThemeLimits.maxNameLength))
        }
        if next.body.count > ThemeLimits.maxBodyLength {
            next.body = String(next.body.prefix(ThemeLimits.maxBodyLength))
        }
        theme.components[index].settings = next
        theme.updatedAt = Date()
        guard commitSettings(theme, componentID: componentID) else {
            theme.components[index].settings = previous
            surfaceByID[componentID]?.update(component: theme.components[index], theme: theme)
            return
        }
        appliedTheme = theme
        if var session {
            self.session = session
            sessionStore.save(session)
        }
        surfaceByID[componentID]?.update(component: theme.components[index], theme: theme)
        if theme.components[index].type == .dock {
            refreshDockGeometry(componentID: componentID)
            syncLoginItem(for: appliedTheme ?? theme)
        }
    }

    /// Shared launch path for the custom dock, app shortcuts, and a future launcher.
    func launchApplication(bundleIdentifier: String, componentID: UUID) {
        let installed = appLauncher.applicationURL(bundleIdentifier: bundleIdentifier) != nil
        if let problem = DockLaunch.problem(bundleIdentifier: bundleIdentifier, isInstalled: installed) {
            surfaceByID[componentID]?.setStatus(problem.message)
            return
        }
        guard let url = appLauncher.applicationURL(bundleIdentifier: bundleIdentifier) else {
            surfaceByID[componentID]?.setStatus(DockLaunchProblem.notInstalled.message)
            return
        }
        surfaceByID[componentID]?.setStatus(nil)
        revealApplications()
        appLauncher.openApplication(at: url) { [weak self] error in
            Task { @MainActor in
                self?.surfaceByID[componentID]?.setStatus(error)
            }
        }
    }

    func hideLauncher() {
        launcherShown = false
        guard let component = appliedTheme?.components.first(where: { $0.type == .launcher }) else { return }
        surfaceByID[component.id]?.setLauncherShown(false)
    }

    func toggleLauncher() {
        guard let component = appliedTheme?.components.first(where: { $0.type == .launcher }),
              surfaceByID[component.id] != nil
        else {
            for candidate in appliedTheme?.components ?? [] where candidate.type == .dock {
                surfaceByID[candidate.id]?.setStatus("Add a Launcher to this theme, then Apply.")
            }
            return
        }
        launcherShown.toggle()
        if launcherShown {
            NSApp.activate(ignoringOtherApps: true)
        }
        surfaceByID[component.id]?.setLauncherShown(launcherShown)
    }

    private func installLauncherHotkey(for theme: Theme) {
        hotkey.onFire = { [weak self] in
            self?.toggleLauncher()
        }
        guard let launcher = theme.components.first(where: { $0.type == .launcher }) else { return }
        let installed = hotkey.install(
            key: launcher.settings.launcherShortcutKey,
            modifiers: launcher.settings.launcherShortcutModifiers
        )
        if !installed {
            surfaceByID[launcher.id]?.setStatus("The launcher shortcut could not be registered. Open it from the dock instead.")
        }
    }

    private func present(
        theme: Theme,
        baseline: Theme,
        placements: [RuntimePlacementRecord],
        title: String
    ) -> DesktopApplyReport {
        let displays = screens.screens()
        guard let fallback = preferredDisplay(in: displays) else {
            return DesktopApplyReport(
                applied: false,
                title: "Theme was not applied",
                message: "No display is available. The editor is still open."
            )
        }

        closeSurfaces()
        var resolved: [RuntimePlacementRecord] = []
        let ordered = theme.components.sorted { lhs, rhs in
            if lhs.frame.zIndex == rhs.frame.zIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.frame.zIndex < rhs.frame.zIndex
        }

        for component in ordered where Self.supportedTypes.contains(component.type) {
            let requested = placements.first(where: { $0.componentID == component.id })?.displayID
            let display = displays.first(where: { $0.id == requested }) ?? fallback
            guard let fitted = fittedCanvas(theme, on: display) else { continue }
            let frame = component.frame.clamped(to: theme.canvas)
            let window = CanvasScreenMapping.windowFrame(component: frame, fitted: fitted)
            var shown = component
            shown.frame = frame
            let surface = surfaces.install(component: shown, theme: theme, windowFrame: window, controller: self)
            surfaceByID[component.id] = surface
            resolved.append(RuntimePlacementRecord(componentID: component.id, displayID: display.id, frame: frame))
        }

        guard !resolved.isEmpty else {
            return DesktopApplyReport(
                applied: false,
                title: "Theme was not applied",
                message: "The theme could not be placed on a display. The editor is still open."
            )
        }

        chrome.hideChrome()
        backdrop.show(theme: theme, displays: displays)
        orderSurfaces(for: theme)
        appliedTheme = theme
        let stored = DesktopExperienceSession(
            active: true,
            themeID: theme.id,
            baseline: baseline,
            placements: resolved
        )
        session = stored
        sessionStore.save(stored)

        let skipped = theme.components.filter { !Self.supportedTypes.contains($0.type) }
        var message = "Opened \(resolved.count) widget \(resolved.count == 1 ? "window" : "windows") for “\(theme.name)”."
        if !skipped.isEmpty {
            let names = skipped.map(\.type.libraryTitle).joined(separator: ", ")
            message += " Skipped \(skipped.count) (\(names))."
        }
        message += " The theme covers the wallpaper, desktop icons, Dock, and menu bar. Open an app from the custom dock to use that app. Right-click a widget and choose Stop Desktop Experience to bring the Mac desktop back."
        syncLoginItem(for: theme)
        installLauncherHotkey(for: theme)
        for component in theme.components where component.type == .launcher {
            surfaceByID[component.id]?.setLauncherShown(false)
        }
        return DesktopApplyReport(applied: true, title: title, message: message)
    }

    private func prepareDocks(in theme: Theme) -> Theme {
        var theme = theme
        var changed = false
        for index in theme.components.indices where theme.components[index].type == .dock || theme.components[index].type == .launcher {
            let current = theme.components[index]
            let fitted: ComponentFrame
            if current.type == .dock {
                fitted = DockLayout.fittedFrame(current.frame, settings: current.settings, canvas: theme.canvas)
            } else {
                fitted = LauncherLayout.fitted(current.frame, placement: current.settings.launcherPlacement, canvas: theme.canvas)
            }
            guard !framesMatch(current.frame, fitted) else { continue }
            theme.components[index].frame = fitted
            changed = true
            if let layoutSink {
                _ = layoutSink.runtimeDidUpdateComponent(
                    themeID: theme.id,
                    componentID: current.id,
                    frame: fitted,
                    settings: nil
                )
            }
        }
        if changed, layoutSink == nil {
            try? themeStore?.save(theme)
        }
        return theme
    }

    private func refreshDockGeometry(componentID: UUID) {
        guard var theme = appliedTheme,
              let index = theme.components.firstIndex(where: { $0.id == componentID }),
              theme.components[index].type == .dock
        else { return }
        let fitted = DockLayout.fittedFrame(
            theme.components[index].frame,
            settings: theme.components[index].settings,
            canvas: theme.canvas
        )
        let previous = theme.components[index].frame
        guard !framesMatch(previous, fitted) else {
            place(componentID: componentID, frame: fitted, theme: theme)
            return
        }
        theme.components[index].frame = fitted
        theme.updatedAt = Date()
        guard commit(theme, componentID: componentID) else { return }
        if let placementIndex = session?.placements.firstIndex(where: { $0.componentID == componentID }) {
            session?.placements[placementIndex].frame = fitted
            if let session {
                sessionStore.save(session)
            }
        }
        appliedTheme = theme
        place(componentID: componentID, frame: fitted, theme: theme)
        surfaceByID[componentID]?.update(component: theme.components[index], theme: theme)
    }

    private func place(componentID: UUID, frame: ComponentFrame, theme: Theme) {
        let displays = screens.screens()
        let displayID = session?.placements.first(where: { $0.componentID == componentID })?.displayID
        let display = displays.first(where: { $0.id == displayID }) ?? preferredDisplay(in: displays)
        guard let display, let fitted = fittedCanvas(theme, on: display) else { return }
        surfaceByID[componentID]?.place(windowFrame: CanvasScreenMapping.windowFrame(component: frame, fitted: fitted))
    }

    private func fittedCanvas(_ theme: Theme, on display: RuntimeDisplay) -> FittedCanvas? {
        CanvasScreenMapping.fit(
            canvasWidth: theme.canvas.width,
            canvasHeight: theme.canvas.height,
            display: display,
            area: .fullFrame
        )
    }

    private func syncLoginItem(for theme: Theme) {
        let enabled = theme.components.contains { $0.type == .dock && $0.settings.launchAtLogin }
        let message = loginItems.apply(enabled: enabled)
        for component in theme.components where component.type == .dock {
            surfaceByID[component.id]?.setStatus(message)
        }
    }

    private func commit(_ theme: Theme, componentID: UUID) -> Bool {
        guard let component = theme.components.first(where: { $0.id == componentID }) else { return false }
        do {
            try theme.validate()
        } catch {
            StudioLog.runtime.error("Rejected a desktop widget edit: \(error.localizedDescription, privacy: .public)")
            return false
        }
        if let layoutSink {
            return layoutSink.runtimeDidUpdateComponent(
                themeID: theme.id,
                componentID: componentID,
                frame: component.frame,
                settings: nil
            )
        }
        do {
            try themeStore?.save(theme)
            return themeStore != nil
        } catch {
            StudioLog.runtime.error("Could not save a desktop widget edit: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func commitSettings(_ theme: Theme, componentID: UUID) -> Bool {
        guard let component = theme.components.first(where: { $0.id == componentID }) else { return false }
        do {
            try theme.validate()
        } catch {
            StudioLog.runtime.error("Rejected a desktop widget edit: \(error.localizedDescription, privacy: .public)")
            return false
        }
        if let layoutSink {
            return layoutSink.runtimeDidUpdateComponent(
                themeID: theme.id,
                componentID: componentID,
                frame: nil,
                settings: component.settings
            )
        }
        do {
            try themeStore?.save(theme)
            return themeStore != nil
        } catch {
            StudioLog.runtime.error("Could not save a desktop widget edit: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func replaceSavedTheme(_ theme: Theme) -> Bool {
        if let layoutSink {
            return layoutSink.runtimeDidReplaceTheme(theme)
        }
        do {
            try themeStore?.save(theme)
            return themeStore != nil
        } catch {
            StudioLog.runtime.error("Could not restore the theme snapshot: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func deactivatePersistedSession() {
        closeSurfaces()
        dismissShell()
        appliedTheme = nil
        if var session {
            session.active = false
            self.session = session
            sessionStore.save(session)
        }
    }

    private func preferredDisplay(in displays: [RuntimeDisplay]) -> RuntimeDisplay? {
        displays.first(where: \.isMain) ?? displays.first
    }

    private func orderSurfaces(for theme: Theme) {
        let layer: DesktopWindowLayer = backdrop.isCoveringTheScreen ? .aboveSystemChrome : .aboveApplications
        let ordered = theme.components.sorted { lhs, rhs in
            if lhs.frame.zIndex == rhs.frame.zIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.frame.zIndex < rhs.frame.zIndex
        }
        for component in ordered {
            surfaceByID[component.id]?.setLayer(layer)
            surfaceByID[component.id]?.orderFront()
        }
    }

    private func revealApplications() {
        backdrop.revealApplications()
        guard let theme = appliedTheme else { return }
        orderSurfaces(for: theme)
    }

    private func dismissShell() {
        backdrop.hide()
        chrome.restoreChrome()
    }

    private func closeSurfaces() {
        hotkey.uninstall()
        launcherShown = false
        for surface in surfaceByID.values {
            surface.close()
        }
        surfaceByID.removeAll()
    }

    private func framesMatch(_ lhs: ComponentFrame, _ rhs: ComponentFrame) -> Bool {
        abs(lhs.x - rhs.x) < 0.5
            && abs(lhs.y - rhs.y) < 0.5
            && abs(lhs.width - rhs.width) < 0.5
            && abs(lhs.height - rhs.height) < 0.5
            && lhs.zIndex == rhs.zIndex
    }
}

@MainActor
final class AppKitScreenProvider: ScreenProviding {
    func screens() -> [RuntimeDisplay] {
        let list = NSScreen.screens
        let main = NSScreen.main
        return list.enumerated().map { index, screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return RuntimeDisplay(
                id: number?.uint32Value ?? UInt32(index + 1),
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                isMain: screen == main
            )
        }
    }
}
