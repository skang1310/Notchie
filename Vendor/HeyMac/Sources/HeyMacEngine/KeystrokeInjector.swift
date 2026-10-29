import Foundation
import Carbon
import ApplicationServices
import CoreGraphics
import HeyMacCore

public enum KeystrokeError: Error {
    case accessibilityNotGranted
    case eventCreationFailed
}

/// Types a password into the lock screen by posting synthetic key events at the HID tap
/// (the level that reaches the secure text field), then presses Return.
public final class KeystrokeInjector: PasswordTyping {
    public init() {}

    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// One key press: what to send and whether to wait after releasing it.
    struct Press {
        var virtualKey: CGKeyCode
        /// Set for text: the character is injected as Unicode so keyboard layout doesn't matter.
        var unicode: [UInt16]?
        var waitAfterRelease: Bool
        var flags: CGEventFlags = []
    }

    private static let returnKey: CGKeyCode = 0x24
    private static let settle: TimeInterval = 0.012

    public func typeAndReturn(_ text: String) throws {
        guard Self.isAccessibilityTrusted() else { throw KeystrokeError.accessibilityNotGranted }
        let source = CGEventSource(stateID: .hidSystemState)
        for press in Self.presses(for: text) {
            try Self.send(press, source: source)
        }
    }

    /// The whole sequence: every character, then Return (which needs no trailing wait).
    struct LayoutKey {
        let code: CGKeyCode
        let flags: CGEventFlags
    }

    static func presses(for text: String, layout: [String: LayoutKey]? = nil) -> [Press] {
        let keys = layout ?? keyboardLayout()
        let characters = text.map { character -> Press in
            let string = String(character)
            let key = keys[string]
            // Supply both representations: secure fields may ignore Unicode overrides.
            return Press(virtualKey: key?.code ?? 0, unicode: Array(string.utf16),
                         waitAfterRelease: true, flags: key?.flags ?? [])
        }
        return characters + [Press(virtualKey: returnKey, unicode: nil, waitAfterRelease: false)]
    }

    /// Resolve the current ASCII-capable layout instead of assuming a US keyboard.
    private static func keyboardLayout() -> [String: LayoutKey] {
        // HIToolbox input-source APIs assert on a background queue, including while locked.
        // Only snapshot the layout on main; key injection and pacing remain on the worker.
        if Thread.isMainThread { return readKeyboardLayoutOnMain() }
        return DispatchQueue.main.sync { readKeyboardLayoutOnMain() }
    }

    private static func readKeyboardLayoutOnMain() -> [String: LayoutKey] {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        let data = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return [:] }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var keys: [String: LayoutKey] = [:]
        let modifiers: [(UInt32, CGEventFlags)] = [(0, []), (UInt32(shiftKey), .maskShift),
            (UInt32(optionKey), .maskAlternate), (UInt32(shiftKey | optionKey), [.maskShift, .maskAlternate])]
        for (modifier, flags) in modifiers {
            for code in UInt16(0)..<UInt16(128) {
                var dead: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 8)
                let status = UCKeyTranslate(layout, code, UInt16(kUCKeyActionDown), modifier >> 8,
                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead,
                    chars.count, &length, &chars)
                guard status == noErr, length > 0 else { continue }
                let string = String(utf16CodeUnits: chars, count: length)
                if keys[string] == nil { keys[string] = LayoutKey(code: code, flags: flags) }
            }
        }
        return keys
    }

    private static func send(_ press: Press, source: CGEventSource?) throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: press.virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: press.virtualKey, keyDown: false)
        else { throw KeystrokeError.eventCreationFailed }

        // Lock shortcuts may still hold Command/Control/Shift when recognition finishes.
        // Synthetic password characters must not inherit those shortcut modifiers.
        down.flags = press.flags
        up.flags = press.flags
        if let unicode = press.unicode {
            unicode.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                for event in [down, up] {
                    event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
                }
            }
        }
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: settle)
        up.post(tap: .cghidEventTap)
        if press.waitAfterRelease { Thread.sleep(forTimeInterval: settle) }
    }
}
