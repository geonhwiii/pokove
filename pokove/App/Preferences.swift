import Foundation
import Observation

/// User preferences, persisted to `UserDefaults` and observable from SwiftUI and services alike.
@Observable
final class Preferences {
    static let shared = Preferences()

    // MARK: General

    var openOnHover: Bool { didSet { store(openOnHover, .openOnHover) } }
    var hoverDelay: Double { didSet { store(hoverDelay, .hoverDelay) } }
    var hapticsEnabled: Bool { didSet { store(hapticsEnabled, .hapticsEnabled) } }
    var showOnAllDisplays: Bool { didSet { store(showOnAllDisplays, .showOnAllDisplays) } }
    var showMenuBarIcon: Bool { didSet { store(showMenuBarIcon, .showMenuBarIcon) } }
    var swipeGesturesEnabled: Bool { didSet { store(swipeGesturesEnabled, .swipeGesturesEnabled) } }
    var hideFromScreenCapture: Bool { didSet { store(hideFromScreenCapture, .hideFromScreenCapture) } }
    var hideInFullscreen: Bool { didSet { store(hideInFullscreen, .hideInFullscreen) } }
    /// Reopen the notch on the page last picked, instead of the one that fits what's going on.
    var openToLastPage: Bool { didSet { store(openToLastPage, .openToLastPage) } }
    /// The page last picked in the open notch (a `NotchPage` raw value).
    var lastNotchPage: String { didSet { store(lastNotchPage, .lastNotchPage) } }

    // MARK: Live activities

    var mediaActivityEnabled: Bool { didSet { store(mediaActivityEnabled, .mediaActivityEnabled) } }
    var showVisualizer: Bool { didSet { store(showVisualizer, .showVisualizer) } }
    var tintWithArtwork: Bool { didSet { store(tintWithArtwork, .tintWithArtwork) } }
    var batteryActivityEnabled: Bool { didSet { store(batteryActivityEnabled, .batteryActivityEnabled) } }
    var lowBatteryAlerts: Bool { didSet { store(lowBatteryAlerts, .lowBatteryAlerts) } }
    var calendarEnabled: Bool { didSet { store(calendarEnabled, .calendarEnabled) } }
    var todosEnabled: Bool { didSet { store(todosEnabled, .todosEnabled) } }
    var clipboardEnabled: Bool { didSet { store(clipboardEnabled, .clipboardEnabled) } }
    /// How many unpinned clipboard items to keep.
    var clipboardLimit: Int { didSet { store(clipboardLimit, .clipboardLimit) } }
    /// Clicking a clipboard item pastes it into the app in front, instead of only copying it.
    var clipboardClickPastes: Bool { didSet { store(clipboardClickPastes, .clipboardClickPastes) } }
    var connectivityEnabled: Bool { didSet { store(connectivityEnabled, .connectivityEnabled) } }

    // MARK: HUD

    var replaceSystemHUD: Bool { didSet { store(replaceSystemHUD, .replaceSystemHUD) } }
    var hudShowsPercentage: Bool { didSet { store(hudShowsPercentage, .hudShowsPercentage) } }

    // MARK: Claude

    var claudeEnabled: Bool { didSet { store(claudeEnabled, .claudeEnabled) } }
    var claudeServerPort: Int { didSet { store(claudeServerPort, .claudeServerPort) } }
    var claudeShowWorking: Bool { didSet { store(claudeShowWorking, .claudeShowWorking) } }
    var claudeNotifyOnDone: Bool { didSet { store(claudeNotifyOnDone, .claudeNotifyOnDone) } }
    var claudeNotifyOnAttention: Bool { didSet { store(claudeNotifyOnAttention, .claudeNotifyOnAttention) } }
    var claudeNotifyOnError: Bool { didSet { store(claudeNotifyOnError, .claudeNotifyOnError) } }
    var claudeApproveFromNotch: Bool { didSet { store(claudeApproveFromNotch, .claudeApproveFromNotch) } }
    var claudeApprovalTimeout: Double { didSet { store(claudeApprovalTimeout, .claudeApprovalTimeout) } }
    var claudePlaySound: Bool { didSet { store(claudePlaySound, .claudePlaySound) } }
    var claudeQuietWhenFocused: Bool { didSet { store(claudeQuietWhenFocused, .claudeQuietWhenFocused) } }
    /// Follow Claude Code's session files, which covers the Claude app, IDEs and the CLI without hooks.
    var watchClaudeSessions: Bool { didSet { store(watchClaudeSessions, .watchClaudeSessions) } }
    var watchCodexSessions: Bool { didSet { store(watchCodexSessions, .watchCodexSessions) } }

    // MARK: Adventure

    var adventureEnabled: Bool { didSet { store(adventureEnabled, .adventureEnabled) } }
    /// Banners for catches, evolutions and boss clears.
    var adventureAnnounceCatches: Bool { didSet { store(adventureAnnounceCatches, .adventureAnnounceCatches) } }
    var adventureSound: Bool { didSet { store(adventureSound, .adventureSound) } }

    // MARK: Language

    /// "system", or a language code pokove should use instead of the system language.
    var appLanguage: String {
        didSet {
            store(appLanguage, .appLanguage)
            // Foundation reads this per app at launch.
            if appLanguage == "system" {
                defaults.removeObject(forKey: "AppleLanguages")
            } else {
                defaults.set([appLanguage], forKey: "AppleLanguages")
            }
        }
    }

    /// The language setting this process started with; a change applies on the next launch.
    let launchLanguage: String

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Self.defaultValues)

        openOnHover = defaults.bool(forKey: Key.openOnHover.rawValue)
        hoverDelay = defaults.double(forKey: Key.hoverDelay.rawValue)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled.rawValue)
        showOnAllDisplays = defaults.bool(forKey: Key.showOnAllDisplays.rawValue)
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon.rawValue)
        swipeGesturesEnabled = defaults.bool(forKey: Key.swipeGesturesEnabled.rawValue)
        hideFromScreenCapture = defaults.bool(forKey: Key.hideFromScreenCapture.rawValue)
        hideInFullscreen = defaults.bool(forKey: Key.hideInFullscreen.rawValue)
        openToLastPage = defaults.bool(forKey: Key.openToLastPage.rawValue)
        lastNotchPage = defaults.string(forKey: Key.lastNotchPage.rawValue) ?? ""

        mediaActivityEnabled = defaults.bool(forKey: Key.mediaActivityEnabled.rawValue)
        showVisualizer = defaults.bool(forKey: Key.showVisualizer.rawValue)
        tintWithArtwork = defaults.bool(forKey: Key.tintWithArtwork.rawValue)
        batteryActivityEnabled = defaults.bool(forKey: Key.batteryActivityEnabled.rawValue)
        lowBatteryAlerts = defaults.bool(forKey: Key.lowBatteryAlerts.rawValue)
        calendarEnabled = defaults.bool(forKey: Key.calendarEnabled.rawValue)
        todosEnabled = defaults.bool(forKey: Key.todosEnabled.rawValue)
        clipboardEnabled = defaults.bool(forKey: Key.clipboardEnabled.rawValue)
        clipboardLimit = defaults.integer(forKey: Key.clipboardLimit.rawValue)
        clipboardClickPastes = defaults.bool(forKey: Key.clipboardClickPastes.rawValue)
        connectivityEnabled = defaults.bool(forKey: Key.connectivityEnabled.rawValue)

        replaceSystemHUD = defaults.bool(forKey: Key.replaceSystemHUD.rawValue)
        hudShowsPercentage = defaults.bool(forKey: Key.hudShowsPercentage.rawValue)

        claudeEnabled = defaults.bool(forKey: Key.claudeEnabled.rawValue)
        claudeServerPort = defaults.integer(forKey: Key.claudeServerPort.rawValue)
        claudeShowWorking = defaults.bool(forKey: Key.claudeShowWorking.rawValue)
        claudeNotifyOnDone = defaults.bool(forKey: Key.claudeNotifyOnDone.rawValue)
        claudeNotifyOnAttention = defaults.bool(forKey: Key.claudeNotifyOnAttention.rawValue)
        claudeNotifyOnError = defaults.bool(forKey: Key.claudeNotifyOnError.rawValue)
        claudeApproveFromNotch = defaults.bool(forKey: Key.claudeApproveFromNotch.rawValue)
        claudeApprovalTimeout = defaults.double(forKey: Key.claudeApprovalTimeout.rawValue)
        claudePlaySound = defaults.bool(forKey: Key.claudePlaySound.rawValue)
        claudeQuietWhenFocused = defaults.bool(forKey: Key.claudeQuietWhenFocused.rawValue)
        watchClaudeSessions = defaults.bool(forKey: Key.watchClaudeSessions.rawValue)
        watchCodexSessions = defaults.bool(forKey: Key.watchCodexSessions.rawValue)

        adventureEnabled = defaults.bool(forKey: Key.adventureEnabled.rawValue)
        adventureAnnounceCatches = defaults.bool(forKey: Key.adventureAnnounceCatches.rawValue)
        adventureSound = defaults.bool(forKey: Key.adventureSound.rawValue)
        let language = defaults.string(forKey: Key.appLanguage.rawValue) ?? "system"
        launchLanguage = language
        appLanguage = language
    }

    private func store(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private enum Key: String {
        case openOnHover, hoverDelay, hapticsEnabled, showOnAllDisplays, showMenuBarIcon
        case swipeGesturesEnabled, hideFromScreenCapture, hideInFullscreen, openToLastPage, lastNotchPage
        case mediaActivityEnabled, showVisualizer, tintWithArtwork
        case batteryActivityEnabled, lowBatteryAlerts, calendarEnabled, connectivityEnabled, todosEnabled
        case clipboardEnabled, clipboardLimit, clipboardClickPastes
        case replaceSystemHUD, hudShowsPercentage
        case claudeEnabled, claudeServerPort, claudeShowWorking
        case claudeNotifyOnDone, claudeNotifyOnAttention, claudeNotifyOnError
        case claudeApproveFromNotch, claudeApprovalTimeout, claudePlaySound, claudeQuietWhenFocused
        case watchClaudeSessions, watchCodexSessions
        case adventureEnabled, adventureAnnounceCatches, adventureSound
        case appLanguage
    }

    private static let defaultValues: [String: Any] = [
        Key.openOnHover.rawValue: true,
        Key.hoverDelay.rawValue: 0.18,
        Key.hapticsEnabled.rawValue: true,
        Key.showOnAllDisplays.rawValue: false,
        Key.showMenuBarIcon.rawValue: true,
        Key.swipeGesturesEnabled.rawValue: true,
        Key.hideFromScreenCapture.rawValue: false,
        Key.hideInFullscreen.rawValue: false,
        Key.openToLastPage.rawValue: true,
        Key.mediaActivityEnabled.rawValue: true,
        Key.showVisualizer.rawValue: true,
        Key.tintWithArtwork.rawValue: true,
        Key.batteryActivityEnabled.rawValue: true,
        Key.lowBatteryAlerts.rawValue: true,
        Key.calendarEnabled.rawValue: true,
        Key.todosEnabled.rawValue: true,
        Key.clipboardEnabled.rawValue: true,
        Key.clipboardLimit.rawValue: 50,
        Key.clipboardClickPastes.rawValue: false,
        Key.connectivityEnabled.rawValue: true,
        Key.replaceSystemHUD.rawValue: true,
        Key.hudShowsPercentage.rawValue: false,
        Key.claudeEnabled.rawValue: true,
        Key.claudeServerPort.rawValue: 47821,
        Key.claudeShowWorking.rawValue: true,
        Key.claudeNotifyOnDone.rawValue: true,
        Key.claudeNotifyOnAttention.rawValue: true,
        Key.claudeNotifyOnError.rawValue: true,
        Key.claudeApproveFromNotch.rawValue: true,
        Key.claudeApprovalTimeout.rawValue: 45.0,
        Key.claudePlaySound.rawValue: false,
        Key.claudeQuietWhenFocused.rawValue: false,
        Key.watchClaudeSessions.rawValue: true,
        Key.watchCodexSessions.rawValue: true,
        Key.adventureEnabled.rawValue: true,
        Key.adventureAnnounceCatches.rawValue: true,
        Key.adventureSound.rawValue: true,
        Key.appLanguage.rawValue: "system",
    ]
}
