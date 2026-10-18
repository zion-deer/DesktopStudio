import SwiftUI

struct DockItemsEditor: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
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
                Label("Add App", systemImage: "plus")
            }
            .accessibilityLabel("Add dock app")
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
            if !SymbolAvailability.exists(item.symbolName) {
                Text("This symbol is not on this Mac, so the icon will look blank.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .background(StudioPalette.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func symbol(_ name: String) -> String {
        SymbolAvailability.exists(name) ? name : "questionmark.square.dashed"
    }
}
