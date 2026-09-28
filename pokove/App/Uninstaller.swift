import AppKit
import ServiceManagement

/// Takes pokove off this Mac at the user's word. The Claude hooks and the login item go; the data,
/// caches and settings (and dancove's, from before the rename, which would otherwise be copied back
/// on a reinstall) move to the Trash with the app, so emptying the Trash is what makes it final.
/// Permissions stay listed in System Settings; macOS keeps those.
enum Uninstaller {
    static func run(app: AppModel) {
        // Nothing may write after the folders go.
        app.stop()
        if app.claude.hookStatus != .notInstalled { try? app.claude.uninstallHooks() }
        try? SMAppService.mainApp.unregister()

        let fileManager = FileManager.default
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let bundleIDs = [Bundle.main.bundleIdentifier ?? "com.geonhwiii.pokove", LegacyMigration.legacyBundleID]
        var folders = ["Application Support/pokove", "Application Support/\(LegacyMigration.legacyName)"]
        for id in bundleIDs {
            folders += ["Caches/\(id)", "HTTPStorages/\(id)", "WebKit/\(id)", "Saved Application State/\(id).savedState"]
        }
        for folder in folders {
            let url = library.appending(path: folder)
            if fileManager.fileExists(atPath: url.path) { try? fileManager.trashItem(at: url, resultingItemURL: nil) }
        }
        // Emptied settings still leave their files behind until they go too.
        for id in bundleIDs { UserDefaults.standard.removePersistentDomain(forName: id) }
        UserDefaults.standard.synchronize()
        for id in bundleIDs {
            let url = library.appending(path: "Preferences/\(id).plist")
            if fileManager.fileExists(atPath: url.path) { try? fileManager.trashItem(at: url, resultingItemURL: nil) }
        }
        try? fileManager.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        // Quit without the usual save on the way out, which would bring a folder back.
        exit(0)
    }
}
