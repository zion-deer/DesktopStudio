import SwiftUI

struct ThemePreviewView: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedTheme.name)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Preview only. This does not change your Mac desktop.")
                        .font(.callout)
                        .foregroundStyle(StudioPalette.textSecondary)
                }
                Spacer()
                Button("Done") {
                    model.isPreviewPresented = false
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close preview")
            }
            .padding(16)
            DesktopCanvasView(isInteractive: false)
        }
        .frame(minWidth: 980, minHeight: 680)
        .background(StudioPalette.stage)
        .preferredColorScheme(.dark)
    }
}
