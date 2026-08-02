import Cocoa
import Carbon

/// Registers a system-wide hotkey using the Carbon API (no accessibility permissions needed).
final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotkey: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onHotkey?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            selfPtr,
            &eventHandler
        )

        // Map Carbon modifier flags
        var carbonMods: UInt32 = 0
        let modFlags = NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        if modFlags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modFlags.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if modFlags.contains(.option) { carbonMods |= UInt32(optionKey) }
        if modFlags.contains(.control) { carbonMods |= UInt32(controlKey) }

        RegisterEventHotKey(
            keyCode,
            carbonMods,
            EventHotKeyID(signature: OSType(0x554E4354), id: UInt32(1)),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
