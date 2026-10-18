import AppKit

enum SymbolAvailability {
    static func exists(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return NSImage(systemSymbolName: trimmed, accessibilityDescription: nil) != nil
    }
}
