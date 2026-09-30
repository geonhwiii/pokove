import AppKit
import Observation
import Sparkle

/// Looks for a newer pokove at launch and once a day through Sparkle, from the appcast on the site
/// (`scripts/appcast.py` writes it), and installs it in place when asked: Sparkle downloads the zip,
/// checks its signature against `SUPublicEDKey`, swaps the app and relaunches it. Nothing about this
/// Mac is sent beyond the app's version in the request.
///
/// pokove lives in the notch, so a new version found in the background opens no window: a banner
/// drops from the notch once (`onFound`, see `UpdateNotices`), the Settings gear gets a dot, and
/// clicking the banner or Settings › About's button shows Sparkle's window.
@Observable
final class UpdateChecker: NSObject {
    struct Release: Equatable {
        let version: String
    }

    /// The newest release, when it's newer than this build.
    private(set) var available: Release?
    /// False until the updater runs, and while Sparkle is busy, so a second check can't start.
    private(set) var canCheck = false

    let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    /// Sparkle keeps this in the app's defaults.
    var checksAutomatically: Bool {
        get {
            access(keyPath: \.checksAutomatically)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.checksAutomatically) { controller.updater.automaticallyChecksForUpdates = newValue }
        }
    }

    /// Set by the app: a background check found this version.
    @ObservationIgnored var onFound: ((String) -> Void)?

    @ObservationIgnored private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: self, userDriverDelegate: self)
    @ObservationIgnored private var busy: NSKeyValueObservation?

    func start() {
        guard busy == nil else { return }
        #if DEBUG
        // `defaults write com.geonhwiii.pokove debugLatestVersion 9.9` pretends a release is out.
        if let version = UserDefaults.standard.string(forKey: "debugLatestVersion") {
            available = Release(version: version)
            onFound?(version)
            return
        }
        // A Debug build only updates from `defaults write com.geonhwiii.pokove debugFeedURL <url>`,
        // so it never replaces itself with a release.
        guard UserDefaults.standard.string(forKey: "debugFeedURL") != nil else { return }
        #endif
        controller.startUpdater()
        busy = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
        }
    }

    #if DEBUG
    /// A scheduled check right now, as if a day had passed.
    func debugCheckInBackground() {
        controller.updater.checkForUpdatesInBackground()
    }
    #endif

    /// Sparkle's window: checking, then the new version's notes with Install, or "up to date".
    func checkNow() {
        guard canCheck else { return }
        NSApp.activate()
        controller.checkForUpdates(nil)
    }
}

extension UpdateChecker: SPUUpdaterDelegate {
    #if DEBUG
    func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: "debugFeedURL")
    }
    #endif

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        available = Release(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        available = nil
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice, forUpdate updateItem: SUAppcastItem,
                 state: SPUUserUpdateState) {
        // Skipped for good; a dismissed one keeps its dot.
        if choice == .skip { available = nil }
    }
}

extension UpdateChecker: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// A scheduled check never opens Sparkle's window by itself; the banner and the gear's dot do the telling.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        onFound?(update.displayVersionString)
        return false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        available = Release(version: update.displayVersionString)
    }
}
