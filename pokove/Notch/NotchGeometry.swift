import AppKit

/// Physical measurements of the notch (or the fake notch drawn on displays without one).
struct NotchGeometry: Equatable {
    /// Size of the hardware cut-out, in points.
    var notchSize: CGSize
    /// Whether the display has a real camera housing.
    var hasPhysicalNotch: Bool
    /// Full frame of the screen that hosts the notch, in global screen coordinates.
    var screenFrame: CGRect

    /// Fallback size used for displays without a notch, matching a 14" MacBook Pro.
    static let fallbackNotchSize = CGSize(width: 185, height: 32)

    init(screen: NSScreen) {
        screenFrame = screen.frame

        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            hasPhysicalNotch = true
            let width = screen.frame.width - left.width - right.width
            notchSize = CGSize(width: width.rounded(), height: topInset)
        } else {
            hasPhysicalNotch = false
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            let height = menuBarHeight > 0 ? min(menuBarHeight, Self.fallbackNotchSize.height) : 24
            notchSize = CGSize(width: Self.fallbackNotchSize.width, height: max(height, 24))
        }
    }

    init(notchSize: CGSize, hasPhysicalNotch: Bool, screenFrame: CGRect) {
        self.notchSize = notchSize
        self.hasPhysicalNotch = hasPhysicalNotch
        self.screenFrame = screenFrame
    }

    static let preview = NotchGeometry(
        notchSize: CGSize(width: 185, height: 32),
        hasPhysicalNotch: true,
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )
}

extension NSScreen {
    /// Stable identifier used to match screens across reconfiguration.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var hasNotch: Bool { safeAreaInsets.top > 0 && auxiliaryTopLeftArea != nil }

    /// The screen with a built-in notch, falling back to the primary display.
    static var notchScreen: NSScreen? {
        screens.first(where: \.hasNotch) ?? screens.first
    }
}
