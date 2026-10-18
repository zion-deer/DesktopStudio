import Carbon.HIToolbox
import Foundation

/// Global shortcut using RegisterEventHotKey. It runs only while Desktop Studio is open and does not require Accessibility.
@MainActor
final class LauncherHotkey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onFire: () -> Void = {}

    func install(key: String, modifiers: [String]) -> Bool {
        uninstall()
        guard let keyCode = LauncherShortcut.carbonKeyCode(for: key) else { return false }
        let modifierBits = LauncherShortcut.carbonModifiers(modifiers)
        guard modifierBits != 0 else { return false }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            desktopLauncherHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard status == noErr else { return false }
        let identifier = EventHotKeyID(signature: OSType(0x4453544C), id: 1)
        let registered = RegisterEventHotKey(
            keyCode,
            modifierBits,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if registered != noErr {
            uninstall()
            return false
        }
        return true
    }

    func uninstall() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}

private func desktopLauncherHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    let hotkey = Unmanaged<LauncherHotkey>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        hotkey.onFire()
    }
    return noErr
}
