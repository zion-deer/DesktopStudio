import Foundation

/// Resolves inherited theme styles and per-component overrides into a concrete appearance.
/// Rendering code calls this. The theme file stores globals and overrides, not the resolved result.
enum StyleResolver {
    static func resolve(_ component: DesktopComponent, theme: Theme) -> ComponentAppearance {
        let style = theme.globals.componentStyles[component.type]
        let globals = theme.globals
        let overrides = component.overrides
        let typography = globals.typography

        let background = overrides.background ?? (style.inheritBackground ? globals.background : style.background)
        let accent = overrides.accent ?? (style.inheritAccent ? globals.accent : style.accent)
        let cornerRadius = overrides.cornerRadius ?? (style.inheritCornerRadius ? globals.cornerRadius : style.cornerRadius)
        let fontSize = overrides.fontSize ?? (style.inheritTypography ? typography.baseFontSize * style.fontScale : style.fontSize)
        let fontDesign = overrides.fontDesign ?? (style.inheritTypography ? typography.fontDesign : style.fontDesign)
        let fontWeight = overrides.fontWeight ?? (style.inheritTypography ? typography.fontWeight : style.fontWeight)

        return ComponentAppearance(
            background: background,
            foreground: overrides.foreground ?? style.foreground,
            accent: accent,
            cornerRadius: cornerRadius,
            opacity: overrides.opacity ?? style.opacity,
            fontSize: fontSize,
            fontDesign: fontDesign,
            fontWeight: fontWeight,
            shadowEnabled: overrides.shadowEnabled ?? style.shadowEnabled,
            borderWidth: overrides.borderWidth ?? style.borderWidth,
            borderColor: overrides.borderColor ?? style.borderColor
        ).sanitized()
    }
}
