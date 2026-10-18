import SwiftUI

struct DockItemsEditor: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InspectorSection(title: "Apps") {
                if let items = model.selectedComponent?.settings.dockItems, !items.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            dockRow(item)
                        }
                    }
                } else {
                    Text("This dock has no apps yet.")
                        .font(.callout)
                        .foregroundStyle(StudioPalette.textSecondary)
                }
                Button {
                    model.addDockItem()
                } label: {
                    Label("Add Placeholder", systemImage: "plus")
                }
                .accessibilityLabel("Add a dock placeholder")
                Button {
                    model.chooseDockApplication()
                } label: {
                    Label("Choose Application…", systemImage: "folder")
                }
                .accessibilityLabel("Choose an application to pin")
                .help("Opens the system file picker. The theme stores the bundle identifier, not the file path.")
            }

            InspectorSection(title: "Dock layout") {
                InspectorSlider(
                    title: "Icon size",
                    value: iconSizeBinding,
                    range: DockLayout.iconSizeRange,
                    step: 2,
                    model: model
                )
                InspectorSlider(
                    title: "Spacing",
                    value: spacingBinding,
                    range: DockLayout.spacingRange,
                    step: 1,
                    model: model
                )
                InspectorSlider(
                    title: "Padding",
                    value: paddingBinding,
                    range: DockLayout.paddingRange,
                    step: 1,
                    model: model
                )
                Picker("Edge", selection: edgeBinding) {
                    ForEach(DockEdge.allCases) { edge in
                        Text(edge.title).tag(edge)
                    }
                }
                .accessibilityLabel("Dock edge")
                .help("Places the custom dock along that edge of the canvas. The system Dock stays where macOS put it.")
                Picker("Alignment", selection: alignmentBinding) {
                    ForEach(DockAlignment.allCases) { alignment in
                        Text(alignment.title(for: model.selectedComponent?.settings.dockEdge ?? .bottom)).tag(alignment)
                    }
                }
                .accessibilityLabel("Dock alignment")
                Text("Background, opacity, and corner radius are in Appearance.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Open Desktop Studio at login", isOn: launchBinding)
                    .accessibilityLabel("Open Desktop Studio at login")
                    .help("Uses the system login-item API. macOS may ask you to approve it. This does not change the system Dock.")
            }
        }
    }

    private func dockRow(_ item: DockItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: symbol(item.symbolName))
                    .frame(width: 18)
                    .foregroundStyle(StudioPalette.accent)
                    .accessibilityHidden(true)
                TextField("Name", text: model.dockItemBinding(item.id, keyPath: \.title))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Dock app name")
                Button {
                    model.moveDockItem(item.id, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Move \(item.title) earlier")
                Button {
                    model.moveDockItem(item.id, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Move \(item.title) later")
                Button(role: .destructive) {
                    model.deleteDockItem(item.id)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(item.title)")
            }
            TextField("Symbol", text: model.dockItemBinding(item.id, keyPath: \.symbolName))
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .accessibilityLabel("Symbol for \(item.title)")
            TextField("Bundle ID", text: model.dockItemBinding(item.id, keyPath: \.bundleIdentifier))
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .accessibilityLabel("Bundle identifier for \(item.title)")
            Toggle("Pinned", isOn: pinBinding(item))
                .accessibilityLabel("Pin \(item.title)")
                .help("Pinned apps stay on the custom dock. Unpinned apps stay in the theme.")
            if !SymbolAvailability.exists(item.symbolName) {
                Text("This symbol is not on this Mac, so the icon falls back when the app icon cannot be read.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(StudioPalette.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func pinBinding(_ item: DockItem) -> Binding<Bool> {
        Binding(
            get: { model.selectedComponent?.settings.dockItems.first { $0.id == item.id }?.pinned ?? item.pinned },
            set: { model.setDockItemPinned(item.id, pinned: $0) }
        )
    }

    private var iconSizeBinding: Binding<Double> {
        Binding(
            get: { model.selectedComponent?.settings.dockIconSize ?? DockLayout.defaultIconSize },
            set: { model.setDockIconSize($0) }
        )
    }

    private var spacingBinding: Binding<Double> {
        Binding(
            get: { model.selectedComponent?.settings.dockSpacing ?? DockLayout.defaultSpacing },
            set: { model.setDockSpacing($0) }
        )
    }

    private var paddingBinding: Binding<Double> {
        Binding(
            get: { model.selectedComponent?.settings.dockPadding ?? DockLayout.defaultPadding },
            set: { model.setDockPadding($0) }
        )
    }

    private var edgeBinding: Binding<DockEdge> {
        Binding(
            get: { model.selectedComponent?.settings.dockEdge ?? .bottom },
            set: { model.setDockEdge($0) }
        )
    }

    private var alignmentBinding: Binding<DockAlignment> {
        Binding(
            get: { model.selectedComponent?.settings.dockAlignment ?? .center },
            set: { model.setDockAlignment($0) }
        )
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { model.selectedComponent?.settings.launchAtLogin ?? false },
            set: { model.setDockLaunchAtLogin($0) }
        )
    }

    private func symbol(_ name: String) -> String {
        SymbolAvailability.exists(name) ? name : "questionmark.square.dashed"
    }
}
