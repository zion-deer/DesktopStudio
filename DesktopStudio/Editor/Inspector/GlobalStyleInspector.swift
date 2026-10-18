import SwiftUI

struct GlobalStyleInspector: View {
    @EnvironmentObject private var model: EditorModel
    @State private var styleType: ComponentType = .clock

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InspectorSection(title: "Theme style") {
                Text("Components inherit these settings until a field is customized.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ColorField(title: "Accent", color: model.themeBinding(\.globals.accent, token: "globals.accent"))
                ColorField(title: "Background", color: model.themeBinding(\.globals.background, token: "globals.background"))
                Picker("Font", selection: model.themeBinding(\.globals.typography.fontDesign, token: "globals.font")) {
                    ForEach(StudioFontDesign.allCases) { design in
                        Text(design.title).tag(design)
                    }
                }
                .accessibilityLabel("Theme font")
                Picker("Weight", selection: model.themeBinding(\.globals.typography.fontWeight, token: "globals.weight")) {
                    ForEach(StudioFontWeight.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }
                .accessibilityLabel("Theme font weight")
                InspectorSlider(
                    title: "Base font size",
                    value: model.themeBinding(\.globals.typography.baseFontSize, token: "globals.fontSize"),
                    range: ComponentAppearance.minimumFontSize...ComponentAppearance.maximumFontSize,
                    step: 1,
                    model: model
                )
                InspectorSlider(
                    title: "Spacing",
                    value: model.themeBinding(\.globals.spacing, token: "globals.spacing"),
                    range: 0...ThemeLimits.maxSpacing,
                    step: 1,
                    model: model
                )
                InspectorSlider(
                    title: "Corner radius",
                    value: model.themeBinding(\.globals.cornerRadius, token: "globals.radius"),
                    range: 0...ComponentAppearance.maximumCornerRadius,
                    step: 1,
                    model: model
                )
                Button("Reset Theme Style") {
                    model.resetGlobalStyle()
                }
                .accessibilityLabel("Reset theme style")
                .help("Restores accent, type, spacing, and default component styles.")
            }

            InspectorSection(title: "Default component style") {
                Picker("Component", selection: $styleType) {
                    ForEach(ComponentType.allCases) { type in
                        Text(type.libraryTitle).tag(type)
                    }
                }
                .accessibilityLabel("Default style component")
                Toggle("Inherit background", isOn: model.styleBinding(type: styleType, keyPath: \.inheritBackground, token: "style.inheritBackground.\(styleType.rawValue)", fallback: false))
                ColorField(title: "Background", color: model.styleBinding(type: styleType, keyPath: \.background, token: "style.background.\(styleType.rawValue)", fallback: ThemeColor(hex: "#000000")))
                ColorField(title: "Foreground", color: model.styleBinding(type: styleType, keyPath: \.foreground, token: "style.foreground.\(styleType.rawValue)", fallback: ThemeColor(hex: "#FFFFFF")))
                Toggle("Inherit accent", isOn: model.styleBinding(type: styleType, keyPath: \.inheritAccent, token: "style.inheritAccent.\(styleType.rawValue)", fallback: true))
                Toggle("Inherit corner radius", isOn: model.styleBinding(type: styleType, keyPath: \.inheritCornerRadius, token: "style.inheritRadius.\(styleType.rawValue)", fallback: true))
                Toggle("Inherit typography", isOn: model.styleBinding(type: styleType, keyPath: \.inheritTypography, token: "style.inheritType.\(styleType.rawValue)", fallback: true))
                InspectorSlider(
                    title: "Font scale",
                    value: model.styleBinding(type: styleType, keyPath: \.fontScale, token: "style.scale.\(styleType.rawValue)", fallback: 1),
                    range: ThemeLimits.minFontScale...ThemeLimits.maxFontScale,
                    step: 0.05,
                    model: model,
                    format: "%.2f"
                )
                Text("Font scale multiplies the base font size when typography is inherited.")
                    .font(.caption)
                    .foregroundStyle(StudioPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.selectedBuiltIn != nil {
                InspectorSection(title: "Built-in theme") {
                    Text("Reset returns this theme’s wallpaper, components, and style to the version shipped with Desktop Studio.")
                        .font(.caption)
                        .foregroundStyle(StudioPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Reset Built-in Theme…") {
                        model.isConfirmingBuiltInReset = true
                    }
                    .accessibilityLabel("Reset built-in theme")
                }
            }
        }
    }
}
