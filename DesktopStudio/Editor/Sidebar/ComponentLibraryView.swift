import SwiftUI

struct ComponentLibraryView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                libraryHeader
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(ComponentType.allCases) { type in
                            LibraryRow(type: type) {
                                model.addComponent(type)
                            }
                        }
                    }
                    .padding(12)
                }
                .frame(height: max(proxy.size.height * 0.58 - 88, 160))
                Divider().overlay(StudioPalette.stroke)
                layerHeader
                ScrollView {
                    if model.frontToBackComponents.isEmpty {
                        Text("Components you add show up here.")
                            .font(.callout)
                            .foregroundStyle(StudioPalette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    } else {
                        VStack(spacing: 2) {
                            ForEach(model.frontToBackComponents) { component in
                                LayerRow(
                                    component: component,
                                    isSelected: model.selectedComponentID == component.id
                                ) {
                                    model.select(component.id)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(StudioPalette.sidebar)
        .accessibilityIdentifier(StudioAccessibilityID.library)
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Components")
                .font(.headline)
                .foregroundStyle(StudioPalette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Click to add, or drag onto the display.")
                .font(.caption)
                .foregroundStyle(StudioPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var layerHeader: some View {
        Text("Layers")
            .font(.headline)
            .foregroundStyle(StudioPalette.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LibraryRow: View {
    var type: ComponentType
    var add: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(StudioPalette.accent.opacity(0.16))
                Image(systemName: type.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StudioPalette.accent)
                    .accessibilityHidden(true)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(type.libraryTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(StudioPalette.textPrimary)
                Text(type.libraryDetail)
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovering ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovering = $0 }
        .onTapGesture(perform: add)
        .draggable(type.rawValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add \(type.libraryTitle)")
        .accessibilityHint("Adds the component to the desktop preview. You can also drag it onto the display.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Add") { add() }
        .help("Add \(type.libraryTitle). Drag it onto the display to choose a position.")
    }
}

private struct LayerRow: View {
    var component: DesktopComponent
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: component.type.symbolName)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? StudioPalette.accent : StudioPalette.textSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(component.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(StudioPalette.textPrimary)
                        .lineLimit(1)
                    Text(component.type.libraryTitle)
                        .font(.caption2)
                        .foregroundStyle(StudioPalette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? StudioPalette.accent.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(component.name), \(component.type.libraryTitle)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Selects this layer")
    }
}
