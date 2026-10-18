import AppKit
import SwiftUI

@MainActor
final class WidgetModel: ObservableObject {
    @Published var component: DesktopComponent
    @Published var theme: Theme
    @Published var status: String?

    init(component: DesktopComponent, theme: Theme) {
        self.component = component
        self.theme = theme
    }
}

struct DesktopWidgetView: View {
    @ObservedObject var model: WidgetModel
    var onCommit: (ComponentSettings) -> Void
    var onOpenApp: (String) -> Void
    var onOpenLauncher: () -> Void = {}
    var onDismissLauncher: () -> Void = {}
    var onStop: () -> Void = {}

    var body: some View {
        if model.component.type == .dock {
            dockBody
        } else if model.component.type == .launcher {
            LauncherWidgetView(
                model: model,
                onLaunch: onOpenApp,
                onDismiss: onDismissLauncher,
                onStop: onStop
            )
        } else {
            standardBody
        }
    }

    private var standardBody: some View {
        let appearance = model.component.resolvedAppearance(in: model.theme)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WindowDragGrip()
                    .frame(width: 18, height: 18)
                    .help("Drag to move this widget. The new position is saved in the theme.")
                Text(model.component.name)
                    .font(.system(size: max(11, appearance.fontSize * 0.28), weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            content(appearance)
            if let status = model.status, !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(appearance.foreground.color.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(appearance.foreground.color)
        .background(appearance.background.color, in: RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                .stroke(appearance.borderColor.color, lineWidth: appearance.borderWidth)
        )
        .opacity(appearance.opacity)
        .shadow(color: appearance.shadowEnabled ? .black.opacity(0.28) : .clear, radius: appearance.shadowEnabled ? 16 : 0, y: 8)
        .contextMenu {
            Button("Stop Desktop Experience") { onStop() }
        }
    }

    private var dockBody: some View {
        let appearance = model.component.resolvedAppearance(in: model.theme)
        return DockWidgetBody(model: model, appearance: appearance, onCommit: onCommit, onOpenApp: onOpenApp, onOpenLauncher: onOpenLauncher, onStop: onStop)
            .padding(model.component.settings.dockPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(appearance.foreground.color)
            .background(appearance.background.color, in: RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                    .stroke(appearance.borderColor.color, lineWidth: appearance.borderWidth)
            )
            .opacity(appearance.opacity)
            .shadow(color: appearance.shadowEnabled ? .black.opacity(0.28) : .clear, radius: appearance.shadowEnabled ? 12 : 0, y: 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Custom dock")
            .help("Desktop Studio dock. The system Dock is unchanged.")
    }

    @ViewBuilder
    private func content(_ appearance: ComponentAppearance) -> some View {
        switch model.component.type {
        case .clock:
            ClockWidgetBody(model: model, appearance: appearance, onCommit: onCommit)
        case .text:
            TextWidgetBody(model: model, appearance: appearance, onCommit: onCommit)
        case .notes:
            NotesWidgetBody(model: model, appearance: appearance, onCommit: onCommit)
        case .appShortcut:
            AppShortcutWidgetBody(model: model, appearance: appearance, onOpenApp: onOpenApp)
        case .dock:
            EmptyView()
        case .launcher:
            EmptyView()
        }
    }
}

private struct DockWidgetBody: View {
    @ObservedObject var model: WidgetModel
    var appearance: ComponentAppearance
    var onCommit: (ComponentSettings) -> Void
    var onOpenApp: (String) -> Void
    var onOpenLauncher: () -> Void
    var onStop: () -> Void
    @State private var hoveredItemID: UUID?

    private var items: [DockItem] {
        model.component.settings.dockItems.filter(\.pinned)
    }

    var body: some View {
        let edge = model.component.settings.dockEdge
        VStack(spacing: 4) {
            if items.isEmpty {
                Text("No pinned apps")
                    .font(.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if edge.isVertical {
                VStack(spacing: model.component.settings.dockSpacing) {
                    iconRow
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: stackAlignment)
            } else {
                HStack(spacing: model.component.settings.dockSpacing) {
                    iconRow
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: stackAlignment)
            }
            Button {
                onOpenLauncher()
            } label: {
                Image(systemName: "magnifyingglass")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open launcher")
            .help("Opens the theme launcher. This does not open the system Dock.")
            if let status = model.status, !status.isEmpty {
                Text(status)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay(alignment: .topLeading) {
            WindowDragGrip()
                .frame(width: 14, height: 14)
                .padding(4)
                .help("Drag along the screen edge. The position is saved in the theme.")
        }
        .contextMenu {
            Button(model.component.settings.launchAtLogin ? "Don’t Open at Login" : "Open Desktop Studio at Login") {
                var settings = model.component.settings
                settings.launchAtLogin.toggle()
                onCommit(settings)
            }
            Button("Stop Desktop Experience") { onStop() }
        }
    }

    private var stackAlignment: Alignment {
        switch model.component.settings.dockAlignment {
        case .leading:
            return model.component.settings.dockEdge.isVertical ? .top : .leading
        case .center:
            return .center
        case .trailing:
            return model.component.settings.dockEdge.isVertical ? .bottom : .trailing
        }
    }

    @ViewBuilder
    private var iconRow: some View {
        ForEach(items) { item in
            dockButton(item)
        }
    }

    private func dockButton(_ item: DockItem) -> some View {
        let installed = DockLaunch.problem(
            bundleIdentifier: item.bundleIdentifier,
            isInstalled: WorkspaceApplicationLauncher().applicationURL(bundleIdentifier: item.bundleIdentifier) != nil
        ) == nil
        let hovering = hoveredItemID == item.id
        return Button {
            onOpenApp(item.bundleIdentifier)
        } label: {
            icon(for: item, installed: installed)
                .frame(width: model.component.settings.dockIconSize, height: model.component.settings.dockIconSize)
        }
        .buttonStyle(DockIconButtonStyle(hovering: hovering))
        .onHover { hovering in
            hoveredItemID = hovering ? item.id : (hoveredItemID == item.id ? nil : hoveredItemID)
        }
        .accessibilityLabel(installed ? "Launch \(item.title)" : "\(item.title), unavailable")
        .accessibilityHint("Opens the application. This is not the system Dock.")
        .contextMenu {
            Button(item.pinned ? "Unpin \(item.title)" : "Pin \(item.title)") {
                setPinned(item, pinned: !item.pinned)
            }
        }
        .help(installed ? "Launch \(item.title)" : DockLaunchProblem.notInstalled.message)
    }

    @ViewBuilder
    private func icon(for item: DockItem, installed: Bool) -> some View {
        if let image = applicationIcon(item.bundleIdentifier) {
            Image(nsImage: image)
                .resizable()
                .opacity(installed ? 1 : 0.4)
                .accessibilityHidden(true)
        } else {
            Image(systemName: symbol(item.symbolName))
                .font(.system(size: model.component.settings.dockIconSize * 0.62))
                .foregroundStyle(appearance.accent.color.opacity(installed ? 1 : 0.45))
                .accessibilityHidden(true)
        }
    }

    private func applicationIcon(_ bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func setPinned(_ item: DockItem, pinned: Bool) {
        var settings = model.component.settings
        guard let index = settings.dockItems.firstIndex(where: { $0.id == item.id }) else { return }
        settings.dockItems[index].pinned = pinned
        onCommit(settings)
    }

    private func symbol(_ name: String) -> String {
        SymbolAvailability.exists(name) ? name : "app.fill"
    }
}

private struct DockIconButtonStyle: ButtonStyle {
    var hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : (hovering ? 1.12 : 1))
            .offset(y: hovering && !configuration.isPressed ? -3 : 0)
            .animation(.easeOut(duration: 0.16), value: hovering)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ClockWidgetBody: View {
    @ObservedObject var model: WidgetModel
    var appearance: ComponentAppearance
    var onCommit: (ComponentSettings) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: model.component.settings.showsSeconds ? 1 : 30)) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(DesktopClockText.timeString(date: context.date, settings: model.component.settings))
                    .font(.system(size: appearance.fontSize, weight: appearance.fontWeight.fontWeight, design: appearance.fontDesign.fontDesign))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                if model.component.settings.showsDate {
                    Text(DesktopClockText.dateString(date: context.date))
                        .font(.system(size: max(12, appearance.fontSize * 0.28), weight: .medium, design: appearance.fontDesign.fontDesign))
                        .lineLimit(2)
                }
            }
        }
        .contextMenu {
            Button("System time") { setFormat(.system) }
            Button("12-hour") { setFormat(.twelveHour) }
            Button("24-hour") { setFormat(.twentyFourHour) }
            Divider()
            Button(model.component.settings.showsDate ? "Hide Date" : "Show Date") {
                var settings = model.component.settings
                settings.showsDate.toggle()
                onCommit(settings)
            }
            Button(model.component.settings.showsSeconds ? "Hide Seconds" : "Show Seconds") {
                var settings = model.component.settings
                settings.showsSeconds.toggle()
                onCommit(settings)
            }
            Divider()
            Button("Stop Desktop Experience") { onStop() }
        }
        .accessibilityLabel("Clock")
    }

    private func setFormat(_ format: TimeFormat) {
        var settings = model.component.settings
        settings.timeFormat = format
        onCommit(settings)
    }
}

private struct TextWidgetBody: View {
    @ObservedObject var model: WidgetModel
    var appearance: ComponentAppearance
    var onCommit: (ComponentSettings) -> Void
    @State private var isEditing = false
    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                TextField("Text", text: $bodyText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Done") {
                    var settings = model.component.settings
                    settings.title = title
                    settings.body = bodyText
                    onCommit(settings)
                    isEditing = false
                }
            } else {
                Text(model.component.settings.title)
                    .font(.system(size: appearance.fontSize, weight: appearance.fontWeight.fontWeight, design: appearance.fontDesign.fontDesign))
                    .lineLimit(2)
                if !model.component.settings.body.isEmpty {
                    Text(model.component.settings.body)
                        .font(.system(size: max(12, appearance.fontSize * 0.45), weight: .regular, design: appearance.fontDesign.fontDesign))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Edit text") {
                    title = model.component.settings.title
                    bodyText = model.component.settings.body
                    isEditing = true
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct NotesWidgetBody: View {
    @ObservedObject var model: WidgetModel
    var appearance: ComponentAppearance
    var onCommit: (ComponentSettings) -> Void
    @State private var draft = ""
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.component.settings.title)
                .font(.system(size: max(13, appearance.fontSize * 0.7), weight: .semibold, design: appearance.fontDesign.fontDesign))
                .lineLimit(1)
            TextEditor(text: $draft)
                .font(.system(size: max(13, appearance.fontSize * 0.75), weight: appearance.fontWeight.fontWeight, design: appearance.fontDesign.fontDesign))
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button("Save note") {
                var settings = model.component.settings
                settings.body = draft
                onCommit(settings)
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            if !didLoad {
                draft = model.component.settings.body
                didLoad = true
            }
        }
        .onChange(of: model.component.settings.body) { _, newValue in
            draft = newValue
        }
    }
}

private struct AppShortcutWidgetBody: View {
    @ObservedObject var model: WidgetModel
    var appearance: ComponentAppearance
    var onOpenApp: (String) -> Void

    var body: some View {
        Button {
            onOpenApp(model.component.settings.bundleIdentifier)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: max(16, appearance.fontSize), weight: .regular))
                    .foregroundStyle(appearance.accent.color)
                    .frame(width: 28)
                Text(model.component.settings.title.isEmpty ? model.component.name : model.component.settings.title)
                    .font(.system(size: max(13, appearance.fontSize), weight: appearance.fontWeight.fontWeight, design: appearance.fontDesign.fontDesign))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(model.component.settings.title)")
        .help("Opens this app if it is installed. Desktop Studio does not replace the Dock.")
    }

    private var symbol: String {
        let name = model.component.settings.symbolName
        if name.isEmpty || !SymbolAvailability.exists(name) {
            return "app"
        }
        return name
    }
}

/// A small grip that starts an AppKit window drag without covering the widget's buttons.
struct WindowDragGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> GripView {
        let view = GripView()
        view.toolTip = "Move widget"
        return view
    }

    func updateNSView(_ nsView: GripView, context: Context) {}

    final class GripView: NSView {
        override var intrinsicContentSize: NSSize { NSSize(width: 18, height: 18) }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.withAlphaComponent(0.55).setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.4
            for row in 0..<3 {
                let y = bounds.midY + CGFloat(row - 1) * 4
                path.move(to: NSPoint(x: bounds.minX + 2, y: y))
                path.line(to: NSPoint(x: bounds.maxX - 2, y: y))
            }
            path.stroke()
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
