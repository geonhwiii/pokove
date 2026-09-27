import Foundation

/// pokove used to be called dancove (bundle `com.geonhwiii.dancove`). On the first launch under the
/// new name, this copies the old settings and the old Application Support folder over, so saves,
/// to-dos and the clipboard history carry on. The old files are left as they were.
nonisolated enum LegacyMigration {
    static let legacyName = "dancove"
    static let legacyBundleID = "com.geonhwiii.dancove"
    private static let doneKey = "migratedFromDancove"

    static func run(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        guard !defaults.bool(forKey: doneKey) else { return }
        if let old = defaults.persistentDomain(forName: legacyBundleID) {
            for (key, value) in old where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let oldFolder = support.appendingPathComponent(legacyName, isDirectory: true)
        let newFolder = support.appendingPathComponent("pokove", isDirectory: true)
        if fileManager.fileExists(atPath: oldFolder.path), !fileManager.fileExists(atPath: newFolder.path) {
            do {
                try fileManager.copyItem(at: oldFolder, to: newFolder)
            } catch {
                // Try again next launch rather than starting over with empty saves.
                NSLog("pokove: couldn't copy \(oldFolder.path): \(error.localizedDescription)")
                return
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}
