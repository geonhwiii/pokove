import Foundation
import Observation

enum HUDKind: Equatable {
    case volume
    case brightness
    case keyboardBacklight

    func symbol(for value: Double, muted: Bool) -> String {
        switch self {
        case .volume:
            if muted || value <= 0.001 { return "speaker.slash.fill" }
            if value < 0.34 { return "speaker.wave.1.fill" }
            if value < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .keyboardBacklight:
            return value <= 0.001 ? "light.min" : "light.max"
        }
    }
}

struct HUDEvent: Equatable {
    var kind: HUDKind
    var value: Double
    var isMuted: Bool = false
    /// +1 / -1 when a key press tried to go past 100% / 0%, for a rubber-band bump.
    var overshoot: Int = 0
    /// Distinguishes repeated presses that produce the same value.
    var serial = 0
}

/// A transient notification that drops out of the notch, like a Dynamic Island alert.
struct NotchBanner: Identifiable, Equatable {
    enum Style: Equatable {
        case claudeFinished
        case claudeNeedsPermission
        case claudeNeedsInput
        case claudeError
        case adventure
        case batteryLow
        case clipboard
        case info
        /// A new pokove is out; clicking opens the updater.
        case update
    }

    let id: UUID
    var style: Style
    var title: String
    var subtitle: String?
    var detail: String?
    /// Links the banner to a Claude session so actions can target it.
    var sessionID: String?
    /// Links the banner to a pending permission request that can be answered inline.
    var permissionID: UUID?
    /// Who turned up at the end of the agent's turn, shown beside the message.
    var encounter: PokeEncounter?
    /// A Pokémon to show on adventure banners (evolutions, legendaries).
    var pokemonID: Int?
    /// A gym badge (1–8) to show on adventure banners.
    var badge: Int?
    /// Which coding agent the banner is about, for its mark and label.
    var agent: AgentKind = .claude
    /// `nil` keeps the banner until it is dismissed explicitly.
    var duration: TimeInterval?

    init(
        style: Style,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        sessionID: String? = nil,
        permissionID: UUID? = nil,
        encounter: PokeEncounter? = nil,
        agent: AgentKind = .claude,
        duration: TimeInterval? = 5
    ) {
        id = UUID()
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.sessionID = sessionID
        self.permissionID = permissionID
        self.encounter = encounter
        pokemonID = encounter?.speciesID
        self.agent = agent
        self.duration = duration
    }

    /// Legendary and mythical catches get a full celebration.
    /// The banner's Pokémon is shiny: a ✦ on its icon.
    var shiny = false

    var celebratesCatch: Bool { encounter?.caught == true && (encounter?.isSpecial == true || encounter?.shiny == true) }

    /// Tall banners carry inline actions or a celebration.
    var isTall: Bool { permissionID != nil || celebratesCatch }
}

/// Coordinates transient notch content (HUDs, banners, flashes) shared by every notch window.
@Observable
final class ActivityCenter {
    private(set) var hud: HUDEvent?
    private(set) var banner: NotchBanner?
    private(set) var chargingFlash = false
    /// A headphone or speaker that just became the audio output.
    private(set) var connection: ConnectionFlash?
    /// Media stays on screen briefly after pausing so a quick resume doesn't flicker.
    private(set) var mediaLingering = false
    /// Media grows taller for a moment to announce a new track.
    private(set) var mediaPeek = false
    /// Incremented whenever something wants every notch to pulse, e.g. a new banner.
    private(set) var attentionTick = 0

    private var queue: [NotchBanner] = []
    private var hudTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?
    private var chargingTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var lingerTask: Task<Void, Never>?
    private var peekTask: Task<Void, Never>?
    private var hudSerial = 0
    /// Pauses banner auto-dismissal while the pointer rests on it.
    private var isBannerHeld = false

    // MARK: HUD

    func showHUD(_ event: HUDEvent) {
        var event = event
        hudSerial &+= 1
        event.serial = hudSerial
        hud = event
        hudTask?.cancel()
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.hud = nil
        }
    }

    // MARK: Media

    func lingerMedia() {
        mediaLingering = true
        lingerTask?.cancel()
        lingerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.mediaLingering = false
        }
    }

    func flashPeek() {
        mediaPeek = true
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            self?.mediaPeek = false
        }
    }

    // MARK: Charging

    func flashCharging() {
        chargingFlash = true
        chargingTask?.cancel()
        chargingTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.chargingFlash = false
        }
    }

    // MARK: Connectivity

    /// Shows a device card with a spinning ring until `completeConnection` resolves it.
    func beginConnection(_ flash: ConnectionFlash) {
        connection = flash
        // Safety net in case the details never arrive.
        scheduleConnectionDismissal(after: 8)
    }

    /// Settles the ring and shows the details, then lets the card go.
    func completeConnection(id: UUID, update: (inout ConnectionFlash) -> Void) {
        guard var flash = connection, flash.id == id else { return }
        update(&flash)
        flash.isConnected = true
        connection = flash
        scheduleConnectionDismissal(after: flash.battery == nil ? 2.6 : 3.6)
    }

    private func scheduleConnectionDismissal(after delay: TimeInterval) {
        connectionTask?.cancel()
        connectionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.connection = nil
        }
    }

    // MARK: Banners

    func post(_ banner: NotchBanner) {
        if let current = self.banner, current.permissionID == nil, banner.permissionID != nil {
            // Permission prompts jump the queue: they block Claude until answered.
            queue.insert(current, at: 0)
            present(banner)
            return
        }
        if self.banner == nil {
            present(banner)
        } else {
            queue.append(banner)
        }
        attentionTick &+= 1
    }

    func dismissBanner(id: UUID) {
        queue.removeAll { $0.id == id }
        guard banner?.id == id else { return }
        advance()
    }

    func dismissBanners(forPermission permissionID: UUID) {
        queue.removeAll { $0.permissionID == permissionID }
        if banner?.permissionID == permissionID { advance() }
    }

    func dismissBanners(forSession sessionID: String, styles: Set<NotchBanner.Style>) {
        queue.removeAll { $0.sessionID == sessionID && styles.contains($0.style) }
        if let banner, banner.sessionID == sessionID, styles.contains(banner.style) { advance() }
    }

    /// Keeps the current banner on screen while the user is looking at it.
    func holdBanner(_ held: Bool) {
        // Only a real hold → release shortens the remaining time; stray releases are no-ops.
        guard held != isBannerHeld else { return }
        isBannerHeld = held
        if held {
            bannerTask?.cancel()
        } else if let banner {
            scheduleDismissal(of: banner, after: 1.5)
        }
    }

    private func present(_ banner: NotchBanner) {
        self.banner = banner
        attentionTick &+= 1
        if !isBannerHeld, let duration = banner.duration {
            scheduleDismissal(of: banner, after: duration)
        } else {
            bannerTask?.cancel()
        }
    }

    private func scheduleDismissal(of banner: NotchBanner, after delay: TimeInterval) {
        guard banner.duration != nil else { return }
        bannerTask?.cancel()
        let id = banner.id
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.dismissBanner(id: id)
        }
    }

    private func advance() {
        bannerTask?.cancel()
        banner = nil
        guard !queue.isEmpty else { return }
        // Leave a beat between banners so the collapse animation reads. The next banner stays
        // in the queue meanwhile, so it can still be dismissed (or overtaken) during the pause.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.banner == nil, !self.queue.isEmpty else { return }
            self.present(self.queue.removeFirst())
        }
    }
}
