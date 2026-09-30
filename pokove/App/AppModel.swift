import AppKit
import Observation

/// Owns the long-lived services shared by every notch window and the settings UI.
@Observable
final class AppModel {
    let preferences: Preferences
    let activity: ActivityCenter
    let nowPlaying: NowPlayingService
    let hud: HUDController
    let battery: BatteryMonitor
    let claude: ClaudeSessionStore
    let adventure: AdventureService
    let calendar: CalendarService
    let todos = TodoStore()
    let clipboard: ClipboardStore
    let audioRoutes: AudioRouteMonitor
    let fullscreen = FullscreenDetector()
    let updates = UpdateChecker()

    init(preferences: Preferences = .shared) {
        let activity = ActivityCenter()
        self.preferences = preferences
        self.activity = activity
        nowPlaying = NowPlayingService()
        hud = HUDController(activity: activity, preferences: preferences)
        battery = BatteryMonitor(activity: activity, preferences: preferences)
        let adventure = AdventureService(preferences: preferences, activity: activity)
        self.adventure = adventure
        let claude = ClaudeSessionStore(activity: activity, preferences: preferences, adventure: adventure)
        self.claude = claude
        adventure.isAgentWorking = { [weak claude] in claude?.isAnyWorking ?? false }
        calendar = CalendarService(preferences: preferences)
        audioRoutes = AudioRouteMonitor(activity: activity, preferences: preferences)
        clipboard = ClipboardStore(activity: activity, preferences: preferences)

        updates.onFound = { [weak activity] version in
            if let banner = UpdateNotices.found(version) { activity?.post(banner) }
        }
        nowPlaying.onTrackChange = { [weak activity] in activity?.flashPeek() }
        nowPlaying.onPlaybackChange = { [weak activity] playing in
            if !playing { activity?.lingerMedia() }
        }
    }

    func start() {
        nowPlaying.start()
        hud.start()
        battery.start()
        claude.start()
        calendar.start()
        audioRoutes.start()
        fullscreen.start()
        clipboard.start()
        adventure.start()
        updates.start()
    }

    func stop() {
        nowPlaying.stop()
        claude.stop()
        adventure.stop()
    }
}
