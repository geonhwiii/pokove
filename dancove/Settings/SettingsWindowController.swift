import AppKit
import SwiftUI

/// Hosts the settings UI in a regular window. dancove is an agent app, so it temporarily
/// becomes a regular app (Dock icon, ⌘-Tab) while settings are open.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let selection = SettingsSelection()

    func show(app: AppModel, pane: SettingsPane? = nil) {
        if let pane { selection.pane = pane }
        app.claude.refreshHookStatus()

        if window == nil {
            let root = SettingsView(selection: selection)
                .environment(app)
                .environment(app.preferences)
            let controller = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: controller)
            window.title = String(localized: "dancove Settings")
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.setContentSize(NSSize(width: 720, height: 520))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }

        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@Observable
final class SettingsSelection {
    var pane: SettingsPane = .general
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case claude
    case adventure
    case nowPlaying
    case calendar
    case clipboard
    case sound
    case battery
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .claude: "Claude Code"
        case .adventure: String(localized: "Adventure")
        case .nowPlaying: String(localized: "Now Playing")
        case .calendar: String(localized: "Calendar & To-dos")
        case .clipboard: String(localized: "Clipboard")
        case .sound: String(localized: "Display & Sound")
        case .battery: String(localized: "Battery & Devices")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .claude: "sparkle"
        case .adventure: "circle.circle.fill"
        case .nowPlaying: "play.circle.fill"
        case .calendar: "calendar"
        case .clipboard: "list.clipboard.fill"
        case .sound: "speaker.wave.2.fill"
        case .battery: "battery.75percent"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .claude: .claude
        case .adventure: .orange
        case .nowPlaying: .pink
        case .calendar: .red
        case .clipboard: .teal
        case .sound: .blue
        case .battery: .green
        case .about: .indigo
        }
    }

    static let sections: [(title: String?, panes: [SettingsPane])] = [
        (nil, [.general]),
        (String(localized: "Live Activities"), [.claude, .adventure, .nowPlaying, .calendar, .clipboard]),
        (String(localized: "Notifications"), [.sound, .battery]),
        ("dancove", [.about]),
    ]
}
