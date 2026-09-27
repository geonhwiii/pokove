import AppKit
import Observation

/// The activities the open notch can show. Like Alcove there is one at a time;
/// swiping down while open (or clicking the page icons) cycles through them.
enum NotchPage: String, CaseIterable, Identifiable {
    case media
    case calendar
    case todos
    case clipboard
    case claude
    case adventure

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .media: "music.note"
        case .calendar: "calendar"
        case .todos: "checklist"
        case .clipboard: "list.clipboard"
        case .claude: "sparkle"
        case .adventure: "pawprint.fill"
        }
    }

    var title: String {
        switch self {
        case .media: String(localized: "Now Playing")
        case .calendar: String(localized: "Calendar")
        case .todos: String(localized: "To-dos")
        case .clipboard: String(localized: "Clipboard")
        case .claude: String(localized: "Claude")
        case .adventure: String(localized: "Adventure")
        }
    }

    /// Pages whose content scrolls vertically, so vertical swipes must not switch pages there.
    var scrollsVertically: Bool { self != .media && self != .calendar }
}

/// Per-window notch state: open/closed, hover, and the presentation derived from app state.
@Observable
final class NotchViewModel {
    private(set) var geometry: NotchGeometry
    private(set) var isOpen = false
    private(set) var isHovering = false
    var isPressed = false
    var page: NotchPage = .media
    /// True while a text field in the notch has the keyboard (adding or editing a to-do).
    private(set) var isEditingText = false
    /// Lets the window controller lend the panel key status while text is being edited.
    @ObservationIgnored var onTextInputChange: ((Bool) -> Void)?

    @ObservationIgnored let app: AppModel
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    /// While true the notch stays open even if the pointer leaves (e.g. during a scrub).
    @ObservationIgnored var isInteracting = false {
        didSet {
            // A scrub released outside the notch skipped the close; do it now.
            if oldValue && !isInteracting && !isHovering && isOpen { scheduleClose() }
        }
    }

    init(geometry: NotchGeometry, app: AppModel) {
        self.geometry = geometry
        self.app = app
    }

    var layout: NotchLayout {
        NotchLayout(
            geometry: geometry,
            showsPartner: app.adventure.isEnabled && app.adventure.leader != nil,
            pageCount: availablePages.count
        )
    }

    func updateGeometry(_ geometry: NotchGeometry) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
    }

    // MARK: Presentation

    var presentation: NotchPresentation {
        if isOpen { return .open }
        let activity = app.activity
        if let hud = activity.hud { return .hud(hud.kind) }
        if let banner = activity.banner { return .banner(id: banner.id, tall: banner.isTall) }
        if activity.chargingFlash { return .compact(.charging) }
        if activity.connection != nil { return .device }
        let compact = compactActivity
        if (compact == .media || compact == .mediaAndClaude) && activity.mediaPeek { return .peek }
        return compact.map(NotchPresentation.compact) ?? .idle
    }

    /// The persistent live activity shown when nothing transient is on screen.
    var compactActivity: CompactActivity? {
        let preferences = app.preferences
        if preferences.claudeEnabled && app.claude.needsAttention { return .claudeAttention }
        if preferences.mediaActivityEnabled && isMediaActive {
            let claudeWorking = preferences.claudeEnabled && preferences.claudeShowWorking && app.claude.isAnyWorking
            return claudeWorking ? .mediaAndClaude : .media
        }
        if preferences.claudeEnabled && preferences.claudeShowWorking && app.claude.isAnyWorking { return .claudeWorking }
        return nil
    }

    /// Media counts as active while playing, and for a few seconds after pausing.
    private var isMediaActive: Bool {
        let media = app.nowPlaying
        guard media.hasMedia else { return false }
        if media.isPlaying { return true }
        return app.activity.mediaLingering
    }

    var size: CGSize { layout.size(for: presentation) }

    /// Pages worth showing right now, in display order.
    var availablePages: [NotchPage] {
        var pages: [NotchPage] = [.media]
        if app.preferences.calendarEnabled { pages.append(.calendar) }
        if app.preferences.todosEnabled { pages.append(.todos) }
        if app.preferences.clipboardEnabled { pages.append(.clipboard) }
        if app.preferences.claudeEnabled { pages.append(.claude) }
        if app.preferences.adventureEnabled { pages.append(.adventure) }
        return pages
    }

    // MARK: Interaction

    func pointerEntered() {
        guard !isHovering else { return }
        isHovering = true
        closeTask?.cancel()
        if case .banner = presentation {
            // Resting on a banner keeps it up; clicking it acts on it.
            app.activity.holdBanner(true)
            return
        }
        if app.preferences.hapticsEnabled && !isOpen {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        guard app.preferences.openOnHover, !isOpen else { return }
        openTask?.cancel()
        let delay = app.preferences.hoverDelay
        openTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.isHovering else { return }
            if case .banner = self.presentation { return }
            self.open()
        }
    }

    func pointerExited() {
        guard isHovering else { return }
        isHovering = false
        isPressed = false
        openTask?.cancel()
        app.activity.holdBanner(false)
        guard isOpen else { return }
        scheduleClose()
    }

    private func scheduleClose() {
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled, let self, !self.isHovering, !self.isInteracting else { return }
            self.close()
        }
    }

    func open(page requested: NotchPage? = nil) {
        openTask?.cancel()
        closeTask?.cancel()
        if let requested {
            page = requested
        } else if !isOpen {
            page = openingPage
        }
        guard !isOpen else { return }
        isOpen = true
        if let banner = app.activity.banner, banner.permissionID == nil {
            app.activity.dismissBanner(id: banner.id)
        }
    }

    func close() {
        openTask?.cancel()
        closeTask?.cancel()
        isOpen = false
        isPressed = false
        endTextInput()
    }

    // MARK: Text input

    /// Borrows the keyboard for a text field; the notch stays open until editing ends.
    func beginTextInput() {
        guard !isEditingText else { return }
        isEditingText = true
        isInteracting = true
        onTextInputChange?(true)
    }

    func endTextInput() {
        guard isEditingText else { return }
        isEditingText = false
        onTextInputChange?(false)
        isInteracting = false
    }

    func toggle() {
        isOpen ? close() : open()
    }

    /// Switches pages at the user's request, and remembers the pick for the next time it opens.
    func select(_ page: NotchPage) {
        self.page = page
        app.preferences.lastNotchPage = page.rawValue
    }

    /// Cycles to the next page (swipe down while open).
    func advancePage() {
        let pages = availablePages
        guard let index = pages.firstIndex(of: page) else {
            select(pages.first ?? .media)
            return
        }
        select(pages[(index + 1) % pages.count])
    }

    /// Where a fresh open lands: the last page picked, unless Claude is blocked on a permission.
    private var openingPage: NotchPage {
        let preferences = app.preferences
        guard preferences.openToLastPage else { return preferredPage }
        if preferences.claudeEnabled && !app.claude.permissions.isEmpty { return .claude }
        if let last = NotchPage(rawValue: preferences.lastNotchPage), availablePages.contains(last) { return last }
        return preferredPage
    }

    /// The page that matches what's going on: Claude when it needs you, media when playing.
    private var preferredPage: NotchPage {
        let preferences = app.preferences
        if preferences.claudeEnabled && app.claude.needsAttention { return .claude }
        if app.nowPlaying.hasMedia { return .media }
        if preferences.claudeEnabled && app.claude.isAnyWorking { return .claude }
        if preferences.calendarEnabled { return .calendar }
        return .media
    }
}
