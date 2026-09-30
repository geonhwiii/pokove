import Foundation

/// The notch's word about versions: a banner when a background check finds a new one, and one
/// after an update that says what it brought. Each shows once per version.
enum UpdateNotices {
    /// What a version brought, for the banner after updating to it or past it. Only versions
    /// worth a line are here; updating across several shows the newest one's.
    static let highlights: [(version: String, text: () -> String, opensAdventure: Bool)] = [
        ("1.3.0", {
            PokeLanguage.isKorean ? "관동 챔피언이 되면 성도로 떠날 수 있어요" : "Become Kanto's Champion to head for Johto"
        }, true),
    ]

    private static let lastLaunchedKey = "lastLaunchedVersion"
    private static let announcedKey = "announcedUpdateVersion"

    /// A background check found `version`: the banner, unless it was already shown for it.
    static func found(_ version: String) -> NotchBanner? {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: announcedKey) != version else { return nil }
        defaults.set(version, forKey: announcedKey)
        return NotchBanner(style: .update, title: String(localized: "A new version is out"), subtitle: "pokove \(version)",
                           detail: String(localized: "Click to update."), duration: 10)
    }

    /// At launch: when this is a newer version than last time, what it brought. `launchedBefore`
    /// covers versions before this one was recorded (1.3.0 and older).
    static func afterUpdate(current: String, launchedBefore: Bool) -> NotchBanner? {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: lastLaunchedKey) ?? (launchedBefore ? "0" : nil)
        defaults.set(current, forKey: lastLaunchedKey)
        guard let previous, isNewer(current, than: previous) else { return nil }
        let brought = highlights.last { isNewer($0.version, than: previous) && !isNewer($0.version, than: current) }
        // A highlight about the adventure opens its page when clicked.
        return NotchBanner(style: brought?.opensAdventure == true ? .adventure : .info,
                           title: String(localized: "Updated"), subtitle: "pokove \(current)",
                           detail: brought?.text(), duration: 8)
    }

    static func isNewer(_ version: String, than other: String) -> Bool {
        version.compare(other, options: .numeric) == .orderedDescending
    }
}
