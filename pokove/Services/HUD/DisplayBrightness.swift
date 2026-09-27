import CoreGraphics
import Foundation

/// Built-in display brightness through the private DisplayServices framework.
enum DisplayBrightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    private static let getBrightness: GetFunction? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetFunction.self)
    }()

    private static let setBrightness: SetFunction? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: SetFunction.self)
    }()

    static var isAvailable: Bool { getBrightness != nil && setBrightness != nil && builtInDisplay != nil }

    /// The built-in panel, which is what the keyboard's brightness keys control.
    static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var brightness: Float? {
        guard let getBrightness, let display = builtInDisplay else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    @discardableResult
    static func set(_ value: Float) -> Bool {
        guard let setBrightness, let display = builtInDisplay else { return false }
        return setBrightness(display, min(max(value, 0), 1)) == 0
    }

    /// Steps brightness like the keyboard does. Returns the new value.
    static func step(by delta: Float) -> Float? {
        guard let current = brightness else { return nil }
        let steps: Float = abs(delta) < 1.0 / 32 ? 64 : 16
        let target = min(max((current * steps + (delta > 0 ? 1 : -1)).rounded() / steps, 0), 1)
        return set(target) ? target : nil
    }
}
