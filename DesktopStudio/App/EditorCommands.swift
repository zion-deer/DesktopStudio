import SwiftUI

struct EditorModelFocusKey: FocusedValueKey {
    typealias Value = EditorModel
}

struct EditorRevisionFocusKey: FocusedValueKey {
    typealias Value = Int
}

extension FocusedValues {
    var editorModel: EditorModel? {
        get { self[EditorModelFocusKey.self] }
        set { self[EditorModelFocusKey.self] = newValue }
    }

    var editorRevision: Int? {
        get { self[EditorRevisionFocusKey.self] }
        set { self[EditorRevisionFocusKey.self] = newValue }
    }
}

struct EditorCommands: Commands {
    @FocusedValue(\.editorModel) private var model
    @FocusedValue(\.editorRevision) private var revision

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Theme") { model?.newTheme() }
                .keyboardShortcut("n")
                .disabled(!actionsEnabled)
            Button("Duplicate Theme") { model?.duplicateSelectedTheme() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(!actionsEnabled)
            Button("Import Theme…") { model?.importTheme() }
                .disabled(!actionsEnabled)
            Button("Export Theme…") { model?.exportSelectedTheme() }
                .disabled(!actionsEnabled)
            Divider()
            Button("Delete Theme…") { model?.isConfirmingThemeDelete = true }
                .disabled(!actionsEnabled)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Theme") { model?.saveSelectedTheme() }
                .keyboardShortcut("s")
                .disabled(model?.isDirty != true)
            Button("Save All Themes") { model?.saveAllDirtyAndReport() }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(model?.hasDirtyThemes != true)
            Button("Revert Theme") { model?.revertSelectedTheme() }
                .disabled(model?.isDirty != true)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model?.undo() }
                .keyboardShortcut("z")
                .disabled(model?.canUndo != true)
            Button("Redo") { model?.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(model?.canRedo != true)
        }

        CommandGroup(after: .pasteboard) {
            Button("Duplicate Component") { model?.duplicateSelectedComponent() }
                .keyboardShortcut("d")
                .disabled(model?.selectedComponentID == nil)
            Button("Delete Component") { model?.deleteSelectedComponent() }
                .keyboardShortcut(.delete)
                .disabled(model?.selectedComponentID == nil)
        }

        CommandMenu("Theme") {
            Button("Preview") { model?.isPreviewPresented = true }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!actionsEnabled)
            Button("Apply…") { model?.applySelectedTheme() }
                .disabled(!actionsEnabled)
            Divider()
            Button(model?.showsGrid == true ? "Hide Grid" : "Show Grid") {
                model?.toggleGrid()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!actionsEnabled)
        }
    }

    /// Reads the focused revision so menu enablement refreshes after edits.
    private var actionsEnabled: Bool {
        model != nil && (revision ?? 0) >= 0
    }
}
