import AppKit
import Observation

final class AppDelegate: NSObject, NSApplicationDelegate {
    let app = AppModel()
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var preferenceTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        app.start()
        rebuildWindows()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
        observeDisplayPreference()
        NotificationCenter.default.addObserver(forName: .dancoveOpenAdventure, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.controllers.values.forEach { controller in
                    guard controller.viewModel.availablePages.contains(.adventure) else { return }
                    controller.viewModel.open(page: .adventure)
                }
            }
        }
        #if DEBUG
        installDebugChannel()
        #endif

        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            app.activity.post(NotchBanner(
                style: .info,
                title: String(localized: "Welcome to dancove"),
                subtitle: String(localized: "Hover the notch to open it"),
                detail: String(localized: "Connect Claude Code in Settings to get notified when Claude needs you."),
                duration: 6
            ))
        }
    }

    #if DEBUG
    /// Lets scripts drive the notch during development:
    /// `notifyutil`-style distributed notification "com.geonhwiii.dancove.debug" with an "action".
    private func installDebugChannel() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.geonhwiii.dancove.debug"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let action = note.object as? String ?? ""
            MainActor.assumeIsolated { self?.handleDebug(action) }
        }
    }

    private func handleDebug(_ action: String) {
        let parts = action.split(separator: " ").map(String.init)
        guard let verb = parts.first else { return }
        let controllers = Array(controllers.values)
        switch verb {
        case "open":
            let page = parts.count > 1 ? NotchPage(rawValue: parts[1]) : nil
            controllers.forEach { $0.viewModel.open(page: page) }
        case "close":
            controllers.forEach { $0.viewModel.close() }
        case "hover":
            controllers.forEach { parts.last == "off" ? $0.viewModel.pointerExited() : $0.viewModel.pointerEntered() }
        case "volume":
            app.activity.showHUD(HUDEvent(kind: .volume, value: Double(parts.last ?? "") ?? 0.5))
        case "brightness":
            app.activity.showHUD(HUDEvent(kind: .brightness, value: Double(parts.last ?? "") ?? 0.5))
        case "charging":
            app.activity.flashCharging()
        case "menubar":
            app.preferences.showMenuBarIcon = parts.last != "off"
        case "airpods":
            app.audioRoutes.previewConnection()
        case "poke":
            // poke starter <id> | poke catch [id] | poke xp <n> | poke stage <w> <s> | poke tick <n> | poke reset
            let arguments = parts.dropFirst(2).compactMap { Int($0) }
            let adventure = app.adventure
            switch parts.count > 1 ? parts[1] : "" {
            case "starter": adventure.chooseStarter(arguments.first ?? 4)
            case "catch":
                if let encounter = adventure.debugCatch(arguments.first) {
                    app.activity.post(NotchBanner(style: .claudeFinished, title: String(localized: "Claude finished"),
                                                  subtitle: "dancove · 3m 12s",
                                                  detail: "Swapped the fishing game for a Pokémon adventure.",
                                                  sessionID: "debug", encounter: encounter,
                                                  duration: encounter.isSpecial ? 9 : 7))
                }
            case "xp": adventure.debugXP(arguments.first ?? 1000)
            case "stage": adventure.debugStage(Stage(world: arguments.first ?? 1, number: arguments.dropFirst().first ?? 1))
            case "tick": adventure.debugTicks(arguments.first ?? 10)
            case "reset": adventure.resetAdventure()
            default: break
            }
        case "todo":
            // todo add <text> | todo type <text> | todo toggle | todo clear
            let text = parts.dropFirst(2).joined(separator: " ")
            switch parts.count > 1 ? parts[1] : "" {
            case "add": app.todos.add(text)
            case "type": NotificationCenter.default.post(name: .dancoveDebugTodo, object: text.isEmpty ? nil : text)
            case "toggle": if let first = app.todos.items.first(where: { !$0.isDone }) { app.todos.toggle(first.id) }
            case "clear": app.todos.items.map(\.id).forEach(app.todos.delete)
            default: break
            }
        case "clip":
            // clip seed | clip clear
            switch parts.count > 1 ? parts[1] : "" {
            case "seed": app.clipboard.debugSeed()
            case "clear": app.clipboard.items.map(\.id).forEach(app.clipboard.delete)
            default: break
            }
        case "keytest":
            // Lends the panel the keyboard and gives it back, logging whether key status moved.
            guard let controller = controllers.first else { return }
            controller.viewModel.beginTextInput()
            let lent = controller.isKeyWindow
            controller.viewModel.endTextInput()
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                let line = "keytest lent=\(lent) returned=\(!controller.isKeyWindow) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-")\n"
                try? line.write(toFile: NSTemporaryDirectory() + "dancove-keytest.txt", atomically: true, encoding: .utf8)
            }
        case "rebuild":
            self.controllers.removeAll()
            rebuildWindows()
        case "select":
            NotificationCenter.default.post(name: .dancoveDebugSelectPokemon, object: parts.count > 1 ? Int(parts[1]) : nil)
        case "peek":
            app.activity.flashPeek()
        case "banner":
            app.activity.post(NotchBanner(style: .claudeFinished, title: "Claude finished", subtitle: "dancove · 2m 14s",
                                          detail: "Added the notch HUD and wired it to the volume keys.", sessionID: "debug"))
        case "toggle":
            app.nowPlaying.togglePlayPause()
        case "next":
            app.nowPlaying.nextTrack()
        case "previous":
            app.nowPlaying.previousTrack()
        case "media":
            switch parts.last {
            case "pause": app.nowPlaying.debugInject(playing: false)
            case "next": app.nowPlaying.debugInject(title: "How Sweet", artist: "NewJeans")
            default: app.nowPlaying.debugInject()
            }
        case "allow", "deny":
            if let request = app.claude.permissions.first {
                app.claude.answer(request.id, with: verb == "allow" ? .allow : .deny)
            }
        case "settings":
            SettingsWindowController.shared.show(app: app, pane: parts.count > 1 ? SettingsPane(rawValue: parts[1]) : nil)
        default:
            break
        }
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        app.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show(app: app)
        return true
    }

    /// Creates, updates or removes notch windows to match the connected displays.
    private func rebuildWindows() {
        let screens = targetScreens()
        let wanted = Set(screens.map(\.displayID))

        for id in controllers.keys where !wanted.contains(id) {
            controllers[id] = nil
        }
        for screen in screens {
            if let controller = controllers[screen.displayID] {
                controller.reposition(on: screen)
            } else {
                controllers[screen.displayID] = NotchWindowController(screen: screen, app: app)
            }
        }
    }

    private func targetScreens() -> [NSScreen] {
        if app.preferences.showOnAllDisplays { return NSScreen.screens }
        return NSScreen.notchScreen.map { [$0] } ?? []
    }

    private func observeDisplayPreference() {
        preferenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.app.preferences.showOnAllDisplays
                    } onChange: {
                        continuation.resume()
                    }
                }
                self.rebuildWindows()
            }
        }
    }
}
