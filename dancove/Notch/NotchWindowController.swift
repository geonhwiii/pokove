import AppKit
import SwiftUI

/// Owns one notch panel on one screen: positioning, hit-testing and gestures.
///
/// The panel is a fixed-size transparent window; only SwiftUI content animates inside it.
/// It ignores mouse events unless the pointer is over the visible notch, so the menu bar
/// underneath keeps working.
final class NotchWindowController {
    let screenID: CGDirectDisplayID
    let viewModel: NotchViewModel
    private let panel: NotchPanel
    private var monitors: [Any] = []
    private var scrollAccumulator = CGSize.zero
    private var scrollGestureFired = false
    private var observationTask: Task<Void, Never>?
    private var pointerPoll: Timer?
    /// True while hidden for a full-screen app.
    private var isSuppressed = false

    init(screen: NSScreen, app: AppModel) {
        screenID = screen.displayID
        viewModel = NotchViewModel(geometry: NotchGeometry(screen: screen), app: app)
        panel = NotchPanel(contentRect: .zero)
        // Size and place the window before SwiftUI content arrives: laying out a live activity in a
        // zero-sized window, then moving it, sends NSHostingView into an update-constraints loop.
        reposition(on: screen)

        let root = NotchRootView(viewModel: viewModel)
            .environment(app)
            .environment(app.preferences)
        let hostingView = NotchHostingView(rootView: root)
        hostingView.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = hostingView

        applyPreferences()
        panel.orderFrontRegardless()
        installMonitors()
        observePreferences()
        viewModel.onTextInputChange = { [weak self] editing in self?.setKeyboardFocus(editing) }
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panelResignedKey() }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            observationTask?.cancel()
            pointerPoll?.invalidate()
            resignKeyObserver.map(NotificationCenter.default.removeObserver)
            monitors.forEach(NSEvent.removeMonitor)
            panel.orderOut(nil)
            panel.close()
        }
    }

    func reposition(on screen: NSScreen) {
        viewModel.updateGeometry(NotchGeometry(screen: screen))
        let size = viewModel.layout.windowSize
        let frame = NSRect(
            x: (screen.frame.midX - size.width / 2).rounded(),
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }

    // MARK: Keyboard

    /// How key focus goes back to the user's app when typing in the notch ends.
    enum FocusReturn: String { case reorder, activate }
    #if DEBUG
    static var focusReturn = FocusReturn(rawValue: UserDefaults.standard.string(forKey: "debugFocusReturn") ?? "") ?? .reorder
    #else
    static let focusReturn = FocusReturn.reorder
    #endif

    /// Lends the panel key status for a text field, then gives it back. The panel is non-activating,
    /// so the user's app stays frontmost the whole time; only key focus moves.
    func setKeyboardFocus(_ editing: Bool) {
        if editing {
            previousApp = NSWorkspace.shared.frontmostApplication
            panel.acceptsKeyboard = true
            if !panel.isKeyWindow { panel.makeKey() }
        } else {
            // Moving straight from one text field to another ends and begins input in one pass;
            // wait a turn so the panel isn't needlessly reordered in between.
            DispatchQueue.main.async { [weak self] in self?.returnKeyFocusIfIdle() }
        }
    }

    private func returnKeyFocusIfIdle() {
        guard !viewModel.isEditingText else { return }
        panel.acceptsKeyboard = false
        guard panel.isKeyWindow else { return }
        switch Self.focusReturn {
        case .reorder:
            // Ordering the key window out makes the window server hand key status back to the
            // frontmost app's window; ordering straight back in keeps the notch on screen.
            panel.orderOut(nil)
            panel.orderFrontRegardless()
        case .activate:
            previousApp?.activate(options: [])
        }
    }

    /// The user took the keyboard elsewhere (Cmd-Tab, clicked another app) mid-edit.
    private func panelResignedKey() {
        guard viewModel.isEditingText else { return }
        viewModel.endTextInput()
    }

    private var previousApp: NSRunningApplication?
    private var resignKeyObserver: NSObjectProtocol?

    var isKeyWindow: Bool { panel.isKeyWindow }

    // MARK: Hit testing

    /// The area that reacts to the pointer, in global screen coordinates.
    private var interactiveRect: NSRect {
        let geometry = viewModel.geometry
        let size = viewModel.size
        let ears = viewModel.layout.cornerRadii(for: viewModel.presentation).top
        var rect = NSRect(
            x: geometry.screenFrame.midX - size.width / 2 - ears,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width + ears * 2,
            height: size.height + 1
        )
        switch viewModel.presentation {
        case .idle, .compact:
            // Reach out a little so the notch reacts as the pointer approaches.
            rect = rect.insetBy(dx: -10, dy: 0)
            rect.origin.y -= 6
            rect.size.height += 6
        case .open:
            rect.origin.y -= 8
            rect.size.height += 8
        default:
            break
        }
        return rect
    }

    private func updateHover(at location: NSPoint) {
        let inside = !isSuppressed && interactiveRect.contains(location)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }
        if inside {
            viewModel.pointerEntered()
            startPointerPolling()
        } else {
            viewModel.pointerExited()
            stopPointerPolling()
        }
    }

    /// While the pointer is over the notch, poll its position as a safety net: some event
    /// routes (drags from other apps, Mission Control) skip both monitors.
    private func startPointerPolling() {
        guard pointerPoll == nil else { return }
        pointerPoll = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateHover(at: NSEvent.mouseLocation)
            }
        }
    }

    private func stopPointerPolling() {
        pointerPoll?.invalidate()
        pointerPoll = nil
    }

    // MARK: Event monitors

    private func installMonitors() {
        let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover(at: NSEvent.mouseLocation) }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mouseEvents, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHover(at: NSEvent.mouseLocation) }
            return event
        }) {
            monitors.append(local)
        }
        // Clicking anywhere else dismisses the open notch.
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.viewModel.isOpen else { return }
                #if DEBUG
                // Screenshots while someone keeps working in other apps.
                if UserDefaults.standard.bool(forKey: "debugHoldOpen") { return }
                #endif
                if !self.interactiveRect.contains(NSEvent.mouseLocation) { self.viewModel.close() }
            }
        }) {
            monitors.append(outside)
        }
        if let scroll = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated { self.handleScroll(event) }
            return handled ? nil : event
        }) {
            monitors.append(scroll)
        }
    }

    /// Two-finger swipes: down opens, up closes, sideways skips tracks.
    private func handleScroll(_ event: NSEvent) -> Bool {
        guard event.window === panel, viewModel.app.preferences.swipeGesturesEnabled else { return false }
        guard event.hasPreciseScrollingDeltas else { return false }

        if event.phase == .began || event.phase == .mayBegin {
            scrollAccumulator = .zero
            scrollGestureFired = false
        }
        // Scrolling pages (Claude sessions, the Pokédex) need the full scroll stream
        // (phases, momentum) to feel right.
        let listOwnsScroll = viewModel.isOpen && viewModel.page.scrollsVertically
        if event.phase == .ended || event.phase == .cancelled {
            scrollAccumulator = .zero
            scrollGestureFired = false
            // A list that saw the gesture begin must also see it end, even if a swipe fired.
            return !listOwnsScroll
        }
        // Momentum events after the fingers lift should not trigger a second action.
        guard event.momentumPhase == [], !scrollGestureFired else { return !listOwnsScroll || scrollGestureFired }

        let inverted = event.isDirectionInvertedFromDevice
        let fingerRight = inverted ? event.scrollingDeltaX : -event.scrollingDeltaX
        let fingerDown = inverted ? event.scrollingDeltaY : -event.scrollingDeltaY
        scrollAccumulator.width += fingerRight
        scrollAccumulator.height += fingerDown

        let horizontal = abs(scrollAccumulator.width) > abs(scrollAccumulator.height) * 1.4
        if horizontal, abs(scrollAccumulator.width) > 44, viewModel.app.nowPlaying.hasMedia {
            scrollGestureFired = true
            if scrollAccumulator.width < 0 {
                viewModel.app.nowPlaying.nextTrack()
            } else {
                viewModel.app.nowPlaying.previousTrack()
            }
            haptic()
            return true
        }
        // Those pages scroll vertically, so vertical swipes belong to their lists there.
        let verticalGesturesAllowed = !viewModel.isOpen || !viewModel.page.scrollsVertically
        if !horizontal, verticalGesturesAllowed, scrollAccumulator.height > 28 {
            scrollGestureFired = true
            if viewModel.isOpen {
                viewModel.advancePage()
                haptic()
            } else {
                viewModel.open()
            }
            return true
        }
        if !horizontal, verticalGesturesAllowed, scrollAccumulator.height < -28, viewModel.isOpen {
            scrollGestureFired = true
            viewModel.close()
            return true
        }
        // Let scroll views inside the open notch (e.g. the Claude list) keep scrolling.
        return !viewModel.isOpen
    }

    private func haptic() {
        guard viewModel.app.preferences.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    // MARK: Preferences

    private func applyPreferences() {
        let app = viewModel.app
        panel.sharingType = app.preferences.hideFromScreenCapture ? .none : .readOnly
        let hidden = app.preferences.hideInFullscreen && app.fullscreen.fullscreenDisplays.contains(screenID)
        if hidden {
            viewModel.close()
            panel.ignoresMouseEvents = true
        }
        isSuppressed = hidden
        panel.animator().alphaValue = hidden ? 0 : 1
    }

    private func observePreferences() {
        let app = viewModel.app
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = app.preferences.hideFromScreenCapture
                        _ = app.preferences.hideInFullscreen
                        _ = app.fullscreen.fullscreenDisplays
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard let self else { return }
                self.applyPreferences()
            }
        }
    }
}
