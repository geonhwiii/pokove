import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Bindable var selection: SettingsSelection

    var body: some View {
        NavigationSplitView {
            List(selection: $selection.pane) {
                ForEach(Array(SettingsPane.sections.enumerated()), id: \.offset) { _, section in
                    Section {
                        ForEach(section.panes) { pane in
                            Label {
                                Text(pane.title)
                            } icon: {
                                SettingsIcon(pane: pane)
                            }
                            .tag(pane)
                        }
                    } header: {
                        if let title = section.title { Text(title) }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selection.pane {
                case .general: GeneralSettingsPane()
                case .claude: ClaudeSettingsPane()
                case .adventure: AdventureSettingsPane()
                case .nowPlaying: NowPlayingSettingsPane()
                case .calendar: CalendarSettingsPane()
                case .clipboard: ClipboardSettingsPane()
                case .sound: SoundSettingsPane()
                case .battery: BatterySettingsPane()
                case .about: AboutSettingsPane()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(selection.pane.title)
        }
        .frame(minWidth: 680, minHeight: 480)
    }
}

private struct SettingsIcon: View {
    let pane: SettingsPane

    var body: some View {
        Group {
            if pane == .claude {
                SparkShape().fill(.white).padding(4)
            } else if pane == .adventure {
                PokeBallGlyph(size: 12).foregroundStyle(.white)
            } else {
                Image(systemName: pane.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: General

private struct GeneralSettingsPane: View {
    @Environment(Preferences.self) private var preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Quits, then reopens from a detached helper once this process is gone, so the new instance
    /// can take over the Claude hook port.
    private func relaunch() {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$2\"",
                            "relaunch", "\(ProcessInfo.processInfo.processIdentifier)", Bundle.main.bundlePath]
        try? helper.run()
        NSApp.terminate(nil)
    }

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Show menu bar icon", isOn: $preferences.showMenuBarIcon)
            }

            Section("Interaction") {
                Toggle("Expand on hover", isOn: $preferences.openOnHover)
                if preferences.openOnHover {
                    LabeledContent("Hover delay") {
                        HStack {
                            Slider(value: $preferences.hoverDelay, in: 0...0.8, step: 0.05)
                                .frame(width: 180)
                            ValuePill(text: String(localized: "\(preferences.hoverDelay, format: .number.precision(.fractionLength(2)))s"))
                        }
                    }
                } else {
                    Text("Click the notch to expand it.")
                        .foregroundStyle(.secondary)
                }
                Toggle("Trackpad gestures", isOn: $preferences.swipeGesturesEnabled)
                Text("Swipe down on the notch to open it or switch activities, swipe up to close, swipe sideways to skip tracks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Haptic feedback", isOn: $preferences.hapticsEnabled)
                Toggle("Reopen to the last page", isOn: $preferences.openToLastPage)
                Text(preferences.openToLastPage
                     ? "The notch opens where you left it. A Claude permission request still comes first."
                     : "The notch opens to what's going on: music while it plays, Claude while it works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Language") {
                Picker("Language", selection: $preferences.appLanguage) {
                    Text("System").tag("system")
                    Text("한국어").tag("ko")
                    Text("English").tag("en")
                }
                if preferences.appLanguage != preferences.launchLanguage {
                    HStack {
                        Text("Relaunch pokove to switch languages.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Relaunch Now", action: relaunch)
                    }
                }
            }

            Section("Displays") {
                Toggle("Show on all displays", isOn: $preferences.showOnAllDisplays)
                Toggle("Hide in full screen", isOn: $preferences.hideInFullscreen)
                Toggle("Hide from screen recordings", isOn: $preferences.hideFromScreenCapture)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Quit pokove") { NSApp.terminate(nil) }
                }
            }
        }
    }
}

// MARK: Claude

private struct ClaudeSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences
    @State private var errorMessage: String?
    @State private var portText = ""

    var body: some View {
        @Bindable var preferences = preferences
        let claude = app.claude
        Form {
            Section {
                HStack(spacing: 14) {
                    ClaudeMark(mode: claude.isAnyWorking ? .working : .still)
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Code in your notch")
                            .font(.headline)
                        Text("See when Claude is working, get notified when it finishes or needs you, and answer permission requests without switching apps.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
                Toggle("Enable Claude integration", isOn: $preferences.claudeEnabled)
                    .onChange(of: preferences.claudeEnabled) { _, enabled in
                        enabled ? claude.start() : claude.stop()
                    }
            }

            Section("Connection") {
                LabeledContent("Hooks") {
                    HStack(spacing: 8) {
                        StatusDot(color: hookColor)
                        Text(hookText)
                            .foregroundStyle(.secondary)
                        switch claude.hookStatus {
                        case .installed:
                            Button("Remove") { run { try claude.uninstallHooks() } }
                        case .outdated:
                            Button("Update") { run { try claude.installHooks() } }
                                .buttonStyle(.borderedProminent)
                        case .notInstalled:
                            Button("Install Hooks") { run { try claude.installHooks() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
                LabeledContent("Listener") {
                    HStack(spacing: 8) {
                        StatusDot(color: serverColor)
                        Text(serverText)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Port") {
                    HStack {
                        TextField("Port", text: $portText)
                            .labelsHidden()
                            .frame(width: 70)
                            .multilineTextAlignment(.trailing)
                            .onSubmit(applyPort)
                        Button("Apply", action: applyPort)
                            .disabled(Int(portText) == preferences.claudeServerPort)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
                Text("pokove adds small hooks to ~/.claude/settings.json that forward Claude's events to 127.0.0.1 with curl, and stay silent when pokove isn't running. Your other settings are kept, and the previous file is saved as settings.json.pokove-backup. Sessions that are already running pick up the hooks after a restart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Detect Claude app, IDE and CLI sessions", isOn: $preferences.watchClaudeSessions)
                    .onChange(of: preferences.watchClaudeSessions) { claude.restartWatcher() }
                Toggle("Detect Codex sessions", isOn: $preferences.watchCodexSessions)
                    .onChange(of: preferences.watchCodexSessions) { claude.restartWatcher() }
            } header: {
                Text("Detection")
            } footer: {
                Text("Follows the session files in ~/.claude/projects and ~/.codex/sessions, so working status and finished alerts need no setup. Answering permission requests from the notch needs the hooks.")
            }

            Section("Notifications") {
                Toggle("Show a live activity while Claude works", isOn: $preferences.claudeShowWorking)
                Toggle("When Claude finishes", isOn: $preferences.claudeNotifyOnDone)
                Toggle("When Claude needs permission or input", isOn: $preferences.claudeNotifyOnAttention)
                Toggle("When a turn fails", isOn: $preferences.claudeNotifyOnError)
                Toggle("Stay quiet while Claude's app is in front", isOn: $preferences.claudeQuietWhenFocused)
                Toggle("Play a sound", isOn: $preferences.claudePlaySound)
            }

            Section("Permission requests") {
                Toggle("Answer from the notch", isOn: $preferences.claudeApproveFromNotch)
                if preferences.claudeApproveFromNotch {
                    LabeledContent("Wait for an answer") {
                        HStack {
                            Slider(value: $preferences.claudeApprovalTimeout, in: 15...180, step: 5)
                                .frame(width: 180)
                            ValuePill(text: ClaudeSessionStore.format(duration: preferences.claudeApprovalTimeout))
                        }
                    }
                }
                Text("When the app running Claude isn't in front, pokove holds the request and shows Allow / Deny in the notch. If you don't answer in time, or switch to that app, Claude asks in its own window as usual.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Active sessions") {
                    Text("\(claude.sessions.count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Preview Notification") { claude.simulateDemo() }
                    Spacer()
                    Button("Clear Finished Sessions") { claude.clearFinished() }
                        .disabled(claude.sessions.isEmpty)
                }
            }
        }
        .onAppear {
            portText = String(preferences.claudeServerPort)
            claude.refreshHookStatus()
        }
    }

    private var hookText: String {
        switch app.claude.hookStatus {
        case .installed: String(localized: "Installed")
        case .outdated: String(localized: "Needs update")
        case .notInstalled: String(localized: "Not installed")
        }
    }

    private var hookColor: Color {
        switch app.claude.hookStatus {
        case .installed: .green
        case .outdated: .orange
        case .notInstalled: .secondary
        }
    }

    private var serverText: String {
        switch app.claude.serverState {
        case .listening(let port): String(localized: "Listening on 127.0.0.1:\(String(port))")
        case .failed(let reason): String(localized: "Failed — \(reason)")
        case .stopped: String(localized: "Stopped")
        }
    }

    private var serverColor: Color {
        switch app.claude.serverState {
        case .listening: .green
        case .failed: .red
        case .stopped: .secondary
        }
    }

    private func applyPort() {
        guard let port = Int(portText), (1024...65535).contains(port) else {
            errorMessage = String(localized: "Choose a port between 1024 and 65535.")
            return
        }
        let wasInstalled = app.claude.hookStatus != .notInstalled
        preferences.claudeServerPort = port
        app.claude.restart()
        if wasInstalled { run { try app.claude.installHooks() } }
        errorMessage = nil
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: Now Playing

private struct NowPlayingSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Show Now Playing live activity", isOn: $preferences.mediaActivityEnabled)
                Toggle("Show waveform", isOn: $preferences.showVisualizer)
                Toggle("Tint with album artwork", isOn: $preferences.tintWithArtwork)
            }
            Section("Source") {
                LabeledContent("Media bridge") {
                    HStack(spacing: 8) {
                        StatusDot(color: app.nowPlaying.isAvailable ? .green : .red)
                        Text(app.nowPlaying.isAvailable ? "Connected" : "Unavailable")
                            .foregroundStyle(.secondary)
                    }
                }
                if let track = app.nowPlaying.track {
                    LabeledContent("Playing") {
                        Text("\(track.title) — \(track.artist)")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Works with Music, Spotify, browsers and any app that reports to Control Center.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Calendar

private struct CalendarSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Show calendar in the notch", isOn: $preferences.calendarEnabled)
                    .onChange(of: preferences.calendarEnabled) { app.calendar.reload() }
                LabeledContent("Access") {
                    HStack(spacing: 8) {
                        StatusDot(color: app.calendar.isAuthorized ? .green : .orange)
                        Text(app.calendar.isAuthorized ? "Granted" : "Not granted")
                            .foregroundStyle(.secondary)
                        if !app.calendar.isAuthorized {
                            Button("Allow…") { app.calendar.requestAccess() }
                        }
                    }
                }
            }

            Section("To-dos") {
                Toggle("Show to-dos in the notch", isOn: $preferences.todosEnabled)
                LabeledContent("Open") {
                    Text("\(app.todos.remainingCount)").monospacedDigit()
                }
                Text("A page beside the calendar. Click \u{201C}New To-do\u{201D} to type; the notch borrows the keyboard only while you type and hands it back when it closes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Clear Completed") { app.todos.clearCompleted() }
                        .disabled(app.todos.doneCount == 0)
                }
            }
        }
    }
}

// MARK: Clipboard

private struct ClipboardSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Keep clipboard history", isOn: $preferences.clipboardEnabled)
                Picker("Keep up to", selection: $preferences.clipboardLimit) {
                    ForEach([20, 50, 100, 200], id: \.self) { count in
                        Text("\(count) items").tag(count)
                    }
                }
                .onChange(of: preferences.clipboardLimit) { app.clipboard.trim() }
                Picker("Clicking an item", selection: $preferences.clipboardClickPastes) {
                    Text("Copies it").tag(false)
                    Text("Pastes it").tag(true)
                }
                LabeledContent("Saved") {
                    Text("\(app.clipboard.items.count)").monospacedDigit()
                }
            }

            Section("Pasting") {
                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        StatusDot(color: app.hud.isTrusted ? .green : .orange)
                        Text(app.hud.isTrusted ? "Granted" : "Not granted")
                            .foregroundStyle(.secondary)
                        if !app.hud.isTrusted {
                            Button("Grant…") {
                                app.hud.requestAccessibility()
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                Text("To paste into the app you're using, pokove presses ⌘V for you, which needs Accessibility access. Without it, items are copied and you paste them yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("Passwords and anything an app marks as confidential are never saved. History stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Clear History") { app.clipboard.clearHistory() }
                        .disabled(app.clipboard.unpinnedCount == 0)
                }
            }
        }
    }
}

// MARK: Display & Sound

private struct SoundSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Replace system volume & brightness HUD", isOn: $preferences.replaceSystemHUD)
                    .onChange(of: preferences.replaceSystemHUD) { app.hud.refresh() }
                Toggle("Show percentage", isOn: $preferences.hudShowsPercentage)
            }
            Section("Permission") {
                LabeledContent("Accessibility") {
                    HStack(spacing: 8) {
                        StatusDot(color: app.hud.isTrusted ? .green : .orange)
                        Text(app.hud.isTrusted ? "Granted" : "Not granted")
                            .foregroundStyle(.secondary)
                        if !app.hud.isTrusted {
                            Button("Grant…") {
                                app.hud.requestAccessibility()
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                Text("pokove listens for the volume and brightness keys and draws its own HUD in the notch. Nothing else is read.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Preview Sound HUD") {
                        app.activity.showHUD(HUDEvent(kind: .volume, value: 0.62))
                    }
                    Button("Preview Display HUD") {
                        app.activity.showHUD(HUDEvent(kind: .brightness, value: Double(DisplayBrightness.brightness ?? 0.7)))
                    }
                }
            }
        }
    }
}

// MARK: Battery

private struct BatterySettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(Preferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section {
                Toggle("Show charging activity", isOn: $preferences.batteryActivityEnabled)
                Toggle("Low battery alerts", isOn: $preferences.lowBatteryAlerts)
            }
            if app.battery.hasBattery {
                Section("Status") {
                    LabeledContent("Level") {
                        HStack(spacing: 6) {
                            Text("\(app.battery.level)%").monospacedDigit()
                            BatteryGlyph(level: app.battery.level, isCharging: app.battery.isCharging, isLowPower: app.battery.isLowPowerMode)
                                .frame(width: 24, height: 12)
                        }
                    }
                    LabeledContent("Power") {
                        Text(app.battery.isPluggedIn ? (app.battery.isCharging ? "Charging" : "Plugged in") : "On battery")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section("Connectivity") {
                Toggle("Announce headphones and speakers", isOn: $preferences.connectivityEnabled)
                Text("Shows the device with its battery when audio switches to AirPods, Bluetooth or AirPlay devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Preview Charging Activity") { app.activity.flashCharging() }
                    Button("Preview Connection") { app.audioRoutes.previewConnection() }
                }
            }
        }
    }
}

// MARK: About

private struct AboutSettingsPane: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        let updates = app.updates
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("pokove")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Version \(updates.current)")
                .foregroundStyle(.secondary)
            Text("Your party travels in the MacBook notch while your agent works.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
            if let release = updates.available {
                Button("Get Version \(release.version)") { openURL(release.page) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: Pieces

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
    }
}

private struct ValuePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .frame(minWidth: 48)
    }
}
