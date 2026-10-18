import SwiftUI

struct PropertiesInspectorView: View {
    @EnvironmentObject private var model: EditorModel
    @State private var section: InspectorTab = .desktop

    private enum InspectorTab: String, CaseIterable, Identifiable {
        case desktop
        case component

        var id: String { rawValue }

        var title: String {
            switch self {
            case .desktop: "Desktop"
            case .component: "Component"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Inspector section", selection: $section) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)
            .accessibilityLabel("Inspector section")

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch section {
                    case .desktop:
                        desktopForm
                    case .component:
                        componentForm
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .background(StudioPalette.inspector)
        .accessibilityIdentifier(StudioAccessibilityID.inspector)
        .onChange(of: model.selectedComponentID) { _, _ in
            section = model.selectedComponentID == nil ? .desktop : .component
        }
    }

    private var desktopForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Themes are saved as JSON on this Mac. Apply opens widget windows, including a custom dock that does not change the system Dock.")
                .font(.callout)
                .foregroundStyle(StudioPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            InspectorSection(title: "Theme") {
                LabeledContent("Name") {
                    TextField("Theme name", text: model.themeBinding(\.name, token: "theme.name"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Theme name")
                }
                .font(.callout)
            }

            InspectorSection(title: "Wallpaper") {
                Picker("Style", selection: wallpaperSelection) {
                    ForEach(WallpaperStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Wallpaper style")
                ColorField(title: "Wallpaper", color: model.themeBinding(\.canvas.background, token: "canvas.background"))
                if model.selectedTheme.canvas.style == .gradient {
                    ColorField(title: "Gradient end", color: model.themeBinding(\.canvas.gradientEnd, token: "canvas.gradient"))
                }
            }

            GlobalStyleInspector()

            InspectorSection(title: "Display") {
                Picker("Preset", selection: presetSelection) {
                    Text("Custom").tag(Optional<CanvasPreset>.none)
                    ForEach(CanvasPreset.allCases) { preset in
                        Text(preset.title).tag(Optional(preset))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Display preset")
                InspectorNumberField(title: "Width", value: widthBinding)
                InspectorNumberField(title: "Height", value: heightBinding)
                Text("\(model.selectedTheme.components.count) components")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var componentForm: some View {
        if let component = model.selectedComponent {
            VStack(alignment: .leading, spacing: 20) {
                InspectorSection(title: "Component") {
                    LabeledContent("Name") {
                        TextField("Name", text: model.componentBinding(\.name, fallback: "", token: "component.name"))
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Component name")
                    }
                    .font(.callout)
                    LabeledContent("Type") {
                        Text(component.type.libraryTitle)
                            .foregroundStyle(StudioPalette.textSecondary)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
                }

                typeSettings(component)

                InspectorSection(title: "Layout") {
                    InspectorNumberField(title: "X", value: frameBinding(\.x))
                    InspectorNumberField(title: "Y", value: frameBinding(\.y))
                    InspectorNumberField(title: "Width", value: frameBinding(\.width))
                    InspectorNumberField(title: "Height", value: frameBinding(\.height))
                    HStack {
                        Button("Bring Forward") { model.bringForward(component.id) }
                            .accessibilityLabel("Bring forward")
                        Button("Send Backward") { model.sendBackward(component.id) }
                            .accessibilityLabel("Send backward")
                    }
                }

                AppearanceInspector()

                InspectorSection(title: "Actions") {
                    HStack {
                        Button("Duplicate") { model.duplicateSelectedComponent() }
                            .accessibilityLabel("Duplicate component")
                        Button("Delete", role: .destructive) { model.deleteSelectedComponent() }
                            .accessibilityLabel("Delete component")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No component selected")
                    .font(.headline)
                    .foregroundStyle(StudioPalette.textPrimary)
                Text("Select a component on the display, or add one from the library.")
                    .font(.callout)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func typeSettings(_ component: DesktopComponent) -> some View {
        switch component.type {
        case .clock:
            InspectorSection(title: "Clock") {
                LabeledContent("Caption") {
                    TextField("Caption", text: model.componentBinding(\.settings.title, fallback: "", token: "clock.caption"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Clock caption")
                }
                Picker("Time format", selection: model.componentBinding(\.settings.timeFormat, fallback: .system, token: "clock.format")) {
                    ForEach(TimeFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .accessibilityLabel("Time format")
                Toggle("Show date", isOn: model.componentBinding(\.settings.showsDate, fallback: true, token: "clock.date"))
                Toggle("Show seconds", isOn: model.componentBinding(\.settings.showsSeconds, fallback: false, token: "clock.seconds"))
            }
        case .text, .notes:
            InspectorSection(title: component.type == .notes ? "Note" : "Text") {
                LabeledContent("Title") {
                    TextField("Title", text: model.componentBinding(\.settings.title, fallback: "", token: "text.title"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Title")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Body")
                        .font(.callout)
                    TextEditor(text: model.componentBinding(\.settings.body, fallback: "", token: "text.body"))
                        .font(.body)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(StudioPalette.elevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("Body")
                }
            }
        case .appShortcut:
            InspectorSection(title: "Shortcut") {
                LabeledContent("App name") {
                    TextField("App name", text: model.componentBinding(\.settings.title, fallback: "", token: "shortcut.title"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("App name")
                }
                LabeledContent("Bundle ID") {
                    TextField("Bundle identifier", text: model.componentBinding(\.settings.bundleIdentifier, fallback: "", token: "shortcut.bundle"))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Bundle identifier")
                }
                symbolField
                Text("Apply opens this shortcut with NSWorkspace when the app is installed.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .dock:
            DockItemsEditor()
        case .launcher:
            LauncherInspector()
        }
    }

    private var symbolField: some View {
        let binding = model.componentBinding(\.settings.symbolName, fallback: "app.fill", token: "shortcut.symbol")
        return VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Symbol") {
                TextField("SF Symbol", text: binding)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .accessibilityLabel("SF Symbol name")
            }
            if !SymbolAvailability.exists(binding.wrappedValue) {
                Text("This symbol is not on this Mac, so the icon will look blank.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var wallpaperSelection: Binding<WallpaperStyle> {
        Binding(
            get: { model.selectedTheme.canvas.style },
            set: { model.setWallpaperStyle($0) }
        )
    }

    private var widthBinding: Binding<Double> {
        Binding(
            get: { model.selectedTheme.canvas.width },
            set: { model.setCanvas(width: $0) }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { model.selectedTheme.canvas.height },
            set: { model.setCanvas(height: $0) }
        )
    }

    private var presetSelection: Binding<CanvasPreset?> {
        Binding(
            get: { CanvasPreset.matching(model.selectedTheme.canvas) },
            set: { preset in
                guard let preset else { return }
                model.setCanvas(width: preset.width, height: preset.height)
            }
        )
    }

    private func frameBinding(_ keyPath: WritableKeyPath<ComponentFrame, Double>) -> Binding<Double> {
        Binding(
            get: { model.selectedComponent?.frame[keyPath: keyPath] ?? 0 },
            set: { newValue in
                model.setSelectedFrame { frame in
                    frame[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

enum CanvasPreset: String, CaseIterable, Identifiable {
    case studio
    case macBook14
    case macBook16
    case hd
    case widescreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studio: "1440 × 900"
        case .macBook14: "1512 × 982"
        case .macBook16: "1728 × 1117"
        case .hd: "1920 × 1080"
        case .widescreen: "2560 × 1440"
        }
    }

    var width: Double {
        switch self {
        case .studio: 1440
        case .macBook14: 1512
        case .macBook16: 1728
        case .hd: 1920
        case .widescreen: 2560
        }
    }

    var height: Double {
        switch self {
        case .studio: 900
        case .macBook14: 982
        case .macBook16: 1117
        case .hd: 1080
        case .widescreen: 1440
        }
    }

    static func matching(_ canvas: CanvasSettings) -> CanvasPreset? {
        allCases.first { $0.width == canvas.width && $0.height == canvas.height }
    }
}
