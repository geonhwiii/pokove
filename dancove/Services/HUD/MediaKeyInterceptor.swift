import AppKit
import ApplicationServices

/// Intercepts the volume and brightness keys so the notch can replace the system HUD.
///
/// Needs Accessibility permission: swallowing an event (returning `nil` from the tap) is
/// what stops macOS from drawing its own overlay.
final class MediaKeyInterceptor {
    enum Key {
        case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    }

    /// Return `true` when the key was handled and should not reach the system.
    var handler: ((_ key: Key, _ fine: Bool) -> Bool)?

    private(set) var isRunning = false
    private var consumedKeys: Set<Key> = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that deep-links to Privacy & Security › Accessibility.
    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }
        guard Self.isTrusted else { return false }

        let mask = CGEventMask(1 << 14) // NX_SYSDEFINED
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyTapCallback,
            userInfo: refcon
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
        isRunning = true
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ event: CGEvent) -> Bool {
        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.type == .systemDefined,
              nsEvent.subtype.rawValue == 8 else { return false }

        let data = nsEvent.data1
        let keyCode = (data & 0xFFFF_0000) >> 16
        let keyFlags = data & 0x0000_FFFF
        let isKeyDown = ((keyFlags & 0xFF00) >> 8) == 0xA

        let key: Key? = switch Int32(keyCode) {
        case NX_KEYTYPE_SOUND_UP: .volumeUp
        case NX_KEYTYPE_SOUND_DOWN: .volumeDown
        case NX_KEYTYPE_MUTE: .mute
        case NX_KEYTYPE_BRIGHTNESS_UP: .brightnessUp
        case NX_KEYTYPE_BRIGHTNESS_DOWN: .brightnessDown
        default: nil
        }
        guard let key, let handler else { return false }
        // Key-ups follow whatever happened to their key-down, so the system never sees half a press.
        guard isKeyDown else { return consumedKeys.remove(key) != nil }
        let fine = nsEvent.modifierFlags.contains([.option, .shift])
        let consumed = handler(key, fine)
        if consumed { consumedKeys.insert(key) } else { consumedKeys.remove(key) }
        return consumed
    }
}

nonisolated private func mediaKeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { interceptor.reenable() }
        return Unmanaged.passUnretained(event)
    }
    let consumed = MainActor.assumeIsolated { interceptor.handle(event) }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
