import AppKit
import Observation

/// Tracks which displays currently show a full-screen app, for "Hide in full screen".
@Observable
final class FullscreenDetector {
    private(set) var fullscreenDisplays: Set<CGDirectDisplayID> = []

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Space switches animate; look again once they settle.
                MainActor.assumeIsolated { self?.refresh() }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    self?.refresh()
                }
            })
        }
        refresh()
    }

    func refresh() {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: Set<CGDirectDisplayID> = []
        for screen in NSScreen.screens {
            // CoreGraphics window bounds use a top-left origin on the primary display.
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            let frame = screen.frame
            let cgFrame = CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
            let covered = windows.contains { info in
                guard (info[kCGWindowLayer as String] as? Int) == 0,
                      (info[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                      let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
                let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
                return abs(rect.minX - cgFrame.minX) < 1 && abs(rect.minY - cgFrame.minY) < 1
                    && abs(rect.width - cgFrame.width) < 1 && abs(rect.height - cgFrame.height) < 1
            }
            if covered { result.insert(screen.displayID) }
        }
        if result != fullscreenDisplays { fullscreenDisplays = result }
    }
}
