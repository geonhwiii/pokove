import SwiftUI

/// Which compact "live activity" wraps around the notch while it is closed.
enum CompactActivity: Equatable {
    case media
    /// Music playing while Claude works: a small spinning spark joins the waveform.
    case mediaAndClaude
    case claudeWorking
    case claudeAttention
    case charging
}

/// Everything the notch can look like. Each case maps to a size and a content view.
enum NotchPresentation: Equatable {
    case idle
    case compact(CompactActivity)
    /// Media activity grown taller to show the new track's title ("QuickPeek").
    case peek
    case hud(HUDKind)
    /// `tall` banners carry inline actions, such as answering a permission request.
    case banner(id: UUID, tall: Bool)
    /// Headphones or a speaker connecting: a card with the device, a spinning ring and battery.
    case device
    case open

    var isOpen: Bool { self == .open }

    /// Presentations that deserve a shadow because they extend below the menu bar.
    var isElevated: Bool {
        switch self {
        case .open, .banner, .peek, .device: true
        default: false
        }
    }

    /// Relative visual weight, used to pick a growing or shrinking spring.
    var magnitude: Int {
        switch self {
        case .idle: 0
        case .compact, .hud: 1
        case .peek: 2
        case .banner, .device: 3
        case .open: 4
        }
    }
}

/// Sizing rules for the notch. All sizes exclude the concave top "ears".
struct NotchLayout {
    let geometry: NotchGeometry
    /// Claude's working activity makes room for the fishing bobber.
    var showsBobber = false
    /// Page tabs in the open header, which must all fit left of the camera housing.
    var pageCount = NotchPage.allCases.count

    var notch: CGSize { geometry.notchSize }

    /// Width of each side wing for compact activities.
    func wingWidth(for activity: CompactActivity) -> CGFloat {
        switch activity {
        case .charging: 88
        case .mediaAndClaude: notch.height + 28
        case .claudeWorking where showsBobber: notch.height + 32
        default: notch.height + 10
        }
    }

    /// Width of each side wing for HUDs: an icon and label on one side, the level on the other.
    static let hudWingWidth: CGFloat = 100
    static let openWidth: CGFloat = 500
    /// One page tab in the open header.
    static let tabSize = CGSize(width: 24, height: 22)
    static let tabSpacing: CGFloat = 1
    static let tabsLeading: CGFloat = 14
    /// Gap kept between the last tab and the camera, so no tab (or its badge) hides under it.
    static let cameraClearance: CGFloat = 8
    static let openContentHeight: CGFloat = 180
    static let bannerWidth: CGFloat = 404
    static let bannerContentHeight: CGFloat = 64
    static let peekContentHeight: CGFloat = 30
    static let deviceWidth: CGFloat = 372
    static let deviceContentHeight: CGFloat = 64

    func size(for presentation: NotchPresentation) -> CGSize {
        switch presentation {
        case .idle:
            return notch
        case .compact(let activity):
            return CGSize(width: notch.width + wingWidth(for: activity) * 2, height: notch.height)
        case .peek:
            return CGSize(width: notch.width + wingWidth(for: .media) * 2 + 60, height: notch.height + Self.peekContentHeight)
        case .hud:
            return CGSize(width: notch.width + 2 * Self.hudWingWidth, height: notch.height)
        case .banner(_, let tall):
            return CGSize(
                width: max(Self.bannerWidth, notch.width + 170) + (tall ? 24 : 0),
                height: notch.height + Self.bannerContentHeight + (tall ? 62 : 0)
            )
        case .device:
            return CGSize(width: max(Self.deviceWidth, notch.width + 180), height: notch.height + Self.deviceContentHeight)
        case .open:
            return CGSize(width: notch.width + 2 * openSideWidth, height: notch.height + Self.openContentHeight)
        }
    }

    /// Width of the open header on either side of the camera: wide enough for every page tab.
    var openSideWidth: CGFloat {
        let count = CGFloat(pageCount)
        let tabs = Self.tabsLeading + count * Self.tabSize.width + max(0, count - 1) * Self.tabSpacing + Self.cameraClearance
        return max((Self.openWidth - notch.width) / 2, 150, tabs.rounded(.up))
    }

    func cornerRadii(for presentation: NotchPresentation) -> (top: CGFloat, bottom: CGFloat) {
        switch presentation {
        case .idle, .compact, .hud: (6, 9 + notch.height / 8)
        case .peek: (8, 18)
        case .banner, .device: (12, 26)
        case .open: (14, 30)
        }
    }

    /// Size of the transparent window that hosts every presentation, including shadow room.
    var windowSize: CGSize {
        // Sized for every page, so turning one on in Settings never outgrows the window.
        var widest = self
        widest.pageCount = NotchPage.allCases.count
        let open = widest.size(for: .open)
        let tallBanner = size(for: .banner(id: UUID(), tall: true))
        return CGSize(
            width: max(open.width, tallBanner.width) + 2 * 16 + 80,
            height: max(open.height, tallBanner.height) + 60
        )
    }
}

extension Animation {
    // Spring constants follow Alcove's (stiffness, damping) pairs, converted to response/damping.

    /// Widening into a live activity (150/20).
    static let notchGrow = Animation.spring(response: 0.51, dampingFraction: 0.82)
    /// Shrinking back toward the notch (175/17.5) — a touch of bounce.
    static let notchShrink = Animation.spring(response: 0.48, dampingFraction: 0.7)
    /// Opening the full notch.
    static let notchOpen = Animation.spring(response: 0.44, dampingFraction: 0.78)
    /// Collapsing the full notch.
    static let notchClose = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// Hover (250/14): very bouncy.
    static let notchHover = Animation.spring(response: 0.4, dampingFraction: 0.5)
    /// Press (160/18).
    static let notchPress = Animation.spring(response: 0.5, dampingFraction: 0.71)

    static func notchTransition(from old: NotchPresentation, to new: NotchPresentation) -> Animation {
        if new == .open { return .notchOpen }
        if old == .open { return .notchClose }
        return new.magnitude >= old.magnitude ? .notchGrow : .notchShrink
    }
}

/// Alcove-style content transition: content blooms out of a blurred sliver.
struct NotchBloom: ViewModifier {
    var blur: CGFloat
    var scaleX: CGFloat
    var scaleY: CGFloat = 1
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scaleX, y: scaleY)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// For content inside compact activities and HUDs.
    static var notchWing: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: NotchBloom(blur: 10, scaleX: 0, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            ).animation(.smooth(duration: 0.3).delay(0.05)),
            removal: .modifier(
                active: NotchBloom(blur: 4, scaleX: 0.25, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            ).animation(.smooth(duration: 0.22))
        )
    }

    /// For the large panels (open notch, banners), which should not squash horizontally.
    static var notchPanel: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: NotchBloom(blur: 12, scaleX: 0.92, scaleY: 0.8, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            ).animation(.smooth(duration: 0.32).delay(0.06)),
            removal: .modifier(
                active: NotchBloom(blur: 6, scaleX: 0.96, scaleY: 0.9, opacity: 0),
                identity: NotchBloom(blur: 0, scaleX: 1, opacity: 1)
            ).animation(.easeOut(duration: 0.14))
        )
    }
}
