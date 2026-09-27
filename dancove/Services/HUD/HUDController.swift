import AppKit
import Observation

/// Replaces the system volume and brightness overlays with notch HUDs.
@Observable
final class HUDController {
    private(set) var isIntercepting = false
    private(set) var isTrusted = MediaKeyInterceptor.isTrusted

    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let interceptor = MediaKeyInterceptor()
    @ObservationIgnored private let volume = SystemVolume()
    @ObservationIgnored private var trustTimer: Timer?
    @ObservationIgnored private var lastKeyChange = Date.distantPast
    @ObservationIgnored private let launchedAt = Date()

    init(activity: ActivityCenter, preferences: Preferences) {
        self.activity = activity
        self.preferences = preferences

        interceptor.handler = { [weak self] key, fine in
            self?.handle(key, fine: fine) ?? false
        }
        volume.onChange = { [weak self] level, muted in
            self?.volumeChangedExternally(level, muted: muted)
        }
    }

    func start() {
        refresh()
        trustTimer?.invalidate()
        // Accessibility can be granted at any time in System Settings; pick it up without a relaunch.
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        isTrusted = MediaKeyInterceptor.isTrusted
        if preferences.replaceSystemHUD && isTrusted {
            if !interceptor.isRunning { interceptor.start() }
        } else if interceptor.isRunning {
            interceptor.stop()
        }
        isIntercepting = interceptor.isRunning
    }

    func requestAccessibility() {
        MediaKeyInterceptor.requestTrust()
    }

    // MARK: Keys

    private func handle(_ key: MediaKeyInterceptor.Key, fine: Bool) -> Bool {
        let delta: Float = fine ? 1.0 / 64 : 1.0 / 16
        switch key {
        case .volumeUp, .volumeDown:
            guard volume.canSetVolume else { return false }
            let before = volume.volume
            let result = volume.step(by: key == .volumeUp ? delta : -delta)
            lastKeyChange = .now
            activity.showHUD(HUDEvent(
                kind: .volume,
                value: Double(result.volume),
                isMuted: result.muted,
                overshoot: Self.overshoot(before: before, up: key == .volumeUp)
            ))
            playFeedbackIfEnabled()
            return true
        case .mute:
            // HDMI / DisplayPort outputs often can't mute; let macOS handle the key then.
            guard volume.canSetMute else { return false }
            let result = volume.toggleMute()
            lastKeyChange = .now
            activity.showHUD(HUDEvent(kind: .volume, value: Double(result.volume), isMuted: result.muted))
            return true
        case .brightnessUp, .brightnessDown:
            let before = DisplayBrightness.brightness ?? 0.5
            guard let value = DisplayBrightness.step(by: key == .brightnessUp ? delta : -delta) else { return false }
            activity.showHUD(HUDEvent(
                kind: .brightness,
                value: Double(value),
                overshoot: Self.overshoot(before: before, up: key == .brightnessUp)
            ))
            return true
        }
    }

    /// Volume changed from Control Center, AirPods, another app… mirror it while we own the HUD.
    private func volumeChangedExternally(_ level: Float, muted: Bool) {
        guard isIntercepting, Date().timeIntervalSince(launchedAt) > 2 else { return }
        guard Date().timeIntervalSince(lastKeyChange) > 0.3 else { return }
        activity.showHUD(HUDEvent(kind: .volume, value: Double(level), isMuted: muted))
    }

    /// Pressing past either end earns a rubber-band bump instead of nothing.
    private static func overshoot(before: Float, up: Bool) -> Int {
        if up && before >= 0.999 { return 1 }
        if !up && before <= 0.001 { return -1 }
        return 0
    }

    private func playFeedbackIfEnabled() {
        let defaults = UserDefaults(suiteName: "NSGlobalDomain")
        guard defaults?.integer(forKey: "com.apple.sound.beep.feedback") == 1 else { return }
        let path = "/System/Library/LoginPlugins/BezelServices.loginPlugin/Contents/Resources/volume.aiff"
        NSSound(contentsOfFile: path, byReference: true)?.play()
    }
}
