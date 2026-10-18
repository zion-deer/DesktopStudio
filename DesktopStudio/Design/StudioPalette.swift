import SwiftUI

enum StudioPalette {
    static let stage = Color(red: 0.055, green: 0.059, blue: 0.071)
    static let sidebar = Color(red: 0.086, green: 0.094, blue: 0.114)
    static let inspector = Color(red: 0.086, green: 0.094, blue: 0.114)
    static let elevated = Color(red: 0.122, green: 0.133, blue: 0.165)
    static let stroke = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.42)
    static let accent = Color(red: 0.478, green: 0.635, blue: 1.0)
}

enum StudioAccessibilityID {
    static let editorRoot = "editorRoot"
    static let previewButton = "previewButton"
    static let applyButton = "applyButton"
    static let saveButton = "saveButton"
    static let themePicker = "themePicker"
    static let canvas = "desktopCanvas"
    static let library = "componentLibrary"
    static let inspector = "propertiesInspector"
}
