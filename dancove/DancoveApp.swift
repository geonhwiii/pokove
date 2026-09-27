import SwiftUI

@main
struct DancoveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        @Bindable var preferences = appDelegate.app.preferences
        MenuBarExtra(isInserted: $preferences.showMenuBarIcon) {
            MenuBarContent(app: appDelegate.app)
        } label: {
            Image(systemName: "capsule.tophalf.filled")
        }
    }
}

private struct MenuBarContent: View {
    let app: AppModel

    var body: some View {
        let claude = app.claude
        if app.preferences.claudeEnabled {
            Text(claudeSummary)
            Divider()
        }
        Button("Settings…") { SettingsWindowController.shared.show(app: app) }
            .keyboardShortcut(",")
        Button("Claude Code Settings…") { SettingsWindowController.shared.show(app: app, pane: .claude) }
        if app.preferences.adventureEnabled {
            Button("Open Pokédex") { NotificationCenter.default.post(name: .dancoveOpenAdventure, object: nil) }
        }
        Divider()
        Button("Preview Claude Notification") { claude.simulateDemo() }
        Divider()
        Button("Quit dancove") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var claudeSummary: String {
        let claude = app.claude
        var parts: [String] = []
        let working = claude.workingSessions.count
        let waiting = claude.attentionSessions.count
        if working > 0 { parts.append(String(localized: "\(working) working")) }
        if waiting > 0 { parts.append(String(localized: "\(waiting) waiting")) }
        let turns = claude.stats.totalTurns
        if turns > 0 { parts.append(String(localized: "Today \(turns) · \(ClaudeSessionStore.format(duration: claude.stats.totalSeconds))")) }
        return parts.isEmpty ? String(localized: "All quiet") : parts.joined(separator: " · ")
    }
}
