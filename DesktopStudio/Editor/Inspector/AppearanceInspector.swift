import SwiftUI

struct AppearanceInspector: View {
    @EnvironmentObject private var model: EditorModel

    var body: some View {
        if let component = model.selectedComponent {
            InspectorSection(title: "Appearance") {
                Text(component.overrides.isEmpty
                    ? "This component uses the theme style."
                    : "Custom fields replace the theme style. Use Theme clears one field.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                colorRow("Background", override: \.background, resolved: \.background, token: "override.background", fallback: component.resolvedAppearance(in: model.selectedTheme).background)
                colorRow("Foreground", override: \.foreground, resolved: \.foreground, token: "override.foreground", fallback: component.resolvedAppearance(in: model.selectedTheme).foreground)
                colorRow("Accent", override: \.accent, resolved: \.accent, token: "override.accent", fallback: component.resolvedAppearance(in: model.selectedTheme).accent)
                colorRow("Border", override: \.borderColor, resolved: \.borderColor, token: "override.border", fallback: component.resolvedAppearance(in: model.selectedTheme).borderColor)
                numberRow("Opacity", override: \.opacity, resolved: \.opacity, token: "override.opacity", range: 0...1, step: 0.05, format: "%.2f", fallback: 1)
                numberRow("Corner radius", override: \.cornerRadius, resolved: \.cornerRadius, token: "override.radius", range: 0...ComponentAppearance.maximumCornerRadius, step: 1, fallback: 0)
                numberRow("Border width", override: \.borderWidth, resolved: \.borderWidth, token: "override.borderWidth", range: 0...ComponentAppearance.maximumBorderWidth, step: 1, fallback: 0)
                numberRow("Font size", override: \.fontSize, resolved: \.fontSize, token: "override.fontSize", range: ComponentAppearance.minimumFontSize...ComponentAppearance.maximumFontSize, step: 1, fallback: 16)
                fontDesignRow
                fontWeightRow
                shadowRow
                Button("Use Theme Style") {
                    model.resetSelectedAppearance()
                }
                .accessibilityLabel("Use theme style")
                .help("Clears every custom appearance field on this component.")
            }
        }
    }

    private func colorRow(
        _ title: String,
        override: WritableKeyPath<AppearanceOverrides, ThemeColor?>,
        resolved: KeyPath<ComponentAppearance, ThemeColor>,
        token: String,
        fallback: ThemeColor
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ColorField(title: title, color: model.overrideBinding(override, resolved: resolved, token: token, fallback: fallback))
            inheritButton(title, isCustom: model.hasOverride(override)) {
                model.clearOverride(override, token: "clear-\(token)")
            }
        }
    }

    private func numberRow(
        _ title: String,
        override: WritableKeyPath<AppearanceOverrides, Double?>,
        resolved: KeyPath<ComponentAppearance, Double>,
        token: String,
        range: ClosedRange<Double>,
        step: Double,
        format: String = "%.0f",
        fallback: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            InspectorSlider(
                title: title,
                value: model.overrideBinding(override, resolved: resolved, token: token, fallback: fallback),
                range: range,
                step: step,
                model: model,
                format: format
            )
            inheritButton(title, isCustom: model.hasOverride(override)) {
                model.clearOverride(override, token: "clear-\(token)")
            }
        }
    }

    private var fontDesignRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Font", selection: model.overrideBinding(\.fontDesign, resolved: \.fontDesign, token: "override.fontDesign", fallback: .standard)) {
                ForEach(StudioFontDesign.allCases) { design in
                    Text(design.title).tag(design)
                }
            }
            .accessibilityLabel("Font design")
            inheritButton("Font", isCustom: model.hasOverride(\.fontDesign)) {
                model.clearOverride(\.fontDesign, token: "clear-font-design")
            }
        }
    }

    private var fontWeightRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Weight", selection: model.overrideBinding(\.fontWeight, resolved: \.fontWeight, token: "override.fontWeight", fallback: .regular)) {
                ForEach(StudioFontWeight.allCases) { weight in
                    Text(weight.title).tag(weight)
                }
            }
            .accessibilityLabel("Font weight")
            inheritButton("Weight", isCustom: model.hasOverride(\.fontWeight)) {
                model.clearOverride(\.fontWeight, token: "clear-font-weight")
            }
        }
    }

    private var shadowRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Shadow", isOn: model.overrideBinding(\.shadowEnabled, resolved: \.shadowEnabled, token: "override.shadow", fallback: false))
            inheritButton("Shadow", isCustom: model.hasOverride(\.shadowEnabled)) {
                model.clearOverride(\.shadowEnabled, token: "clear-shadow")
            }
        }
    }

    private func inheritButton(_ title: String, isCustom: Bool, clear: @escaping () -> Void) -> some View {
        HStack {
            Text(isCustom ? "Custom" : "Theme style")
                .font(.caption)
                .foregroundStyle(isCustom ? StudioPalette.accent : StudioPalette.textTertiary)
            Spacer()
            Button("Use Theme") {
                clear()
            }
            .disabled(!isCustom)
            .accessibilityLabel("Use theme \(title)")
        }
    }
}
