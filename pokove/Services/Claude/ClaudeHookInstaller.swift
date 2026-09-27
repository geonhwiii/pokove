import Foundation

/// Adds or removes pokove's HTTP hooks in `~/.claude/settings.json`, leaving every other
/// setting and hook untouched. A backup of the original file is written before each change.
nonisolated struct ClaudeHookInstaller {
    enum Status: Equatable {
        case notInstalled
        case installed
        /// Hooks exist but point at a different port or miss events added in newer versions.
        case outdated
    }

    enum InstallError: LocalizedError {
        case unreadableSettings(String)

        var errorDescription: String? {
            switch self {
            case .unreadableSettings(let reason):
                String(localized: "~/.claude/settings.json could not be parsed: \(reason). Fix the file and try again.")
            }
        }
    }

    /// Events pokove listens to, with the hook timeout (seconds) for each.
    static let events: [(name: String, timeout: Int)] = [
        ("SessionStart", 3),
        ("UserPromptSubmit", 3),
        ("PreToolUse", 3),
        ("PostToolUse", 3),
        ("PostToolUseFailure", 3),
        ("PermissionRequest", 300),
        ("Notification", 3),
        ("SubagentStart", 3),
        ("SubagentStop", 3),
        ("PreCompact", 3),
        ("PostCompact", 3),
        ("Stop", 3),
        ("StopFailure", 3),
        ("SessionEnd", 1),
    ]

    static let marker = "/claude/hook"
    /// The header hooks installed before the rename (as dancove) send.
    private static let legacyHeader = "X-Dancove-Host"

    var settingsURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/settings.json")

    var port: Int

    var hookURL: String { "http://127.0.0.1:\(port)\(Self.marker)" }

    func status() -> Status {
        guard let root = try? readSettings(), let hooks = root["hooks"] as? [String: Any] else { return .notInstalled }
        var found = 0
        var current = true
        for event in Self.events {
            let urls = Self.pokoveURLs(in: hooks[event.name])
            if !urls.isEmpty { found += 1 }
            if urls.contains(where: { $0 != hookURL }) || urls.isEmpty { current = false }
        }
        if found == 0 { return .notInstalled }
        return current ? .installed : .outdated
    }

    /// The shell command each hook runs. It forwards the event JSON from stdin to the app,
    /// tagging it with the hosting app and Claude's PID, and stays silent if pokove is not running.
    func command(timeout: Int) -> String {
        [
            "curl -s -m \(timeout) -X POST",
            "-H 'Content-Type: application/json'",
            "-H \"X-Pokove-Host: ${__CFBundleIdentifier:-}\"",
            "-H \"X-Pokove-Term: ${TERM_PROGRAM:-}\"",
            "-H \"X-Pokove-PID: $PPID\"",
            "--data-binary @- \(hookURL) 2>/dev/null || true",
        ].joined(separator: " ")
    }

    func install() throws {
        var root = try readSettings()
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in Self.events {
            var groups = Self.removingPokove(from: hooks[event.name])
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": command(timeout: event.timeout),
                    // Claude's own limit sits just above curl's so curl always answers first.
                    "timeout": event.timeout + 5,
                ] as [String: Any]],
            ])
            hooks[event.name] = groups
        }
        root["hooks"] = hooks
        try write(root)
    }

    func uninstall() throws {
        var root = try readSettings()
        guard var hooks = root["hooks"] as? [String: Any] else { return }
        for (name, value) in hooks {
            // Leave anything that isn't in the shape we write exactly as it was.
            guard value is [[String: Any]] else { continue }
            let groups = Self.removingPokove(from: value)
            hooks[name] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        try write(root)
    }

    // MARK: File access

    private func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw InstallError.unreadableSettings("top level is not an object")
            }
            return object
        } catch let error as InstallError {
            throw error
        } catch {
            throw InstallError.unreadableSettings(error.localizedDescription)
        }
    }

    /// The real file behind `settingsURL`, so dotfile symlinks (stow, chezmoi) survive writes.
    private var fileURL: URL { settingsURL.resolvingSymlinksInPath() }

    private func write(_ root: [String: Any]) throws {
        let fileManager = FileManager.default
        let fileURL = fileURL
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Keep the very first backup: it is the settings file from before pokove touched it.
        let folder = settingsURL.deletingLastPathComponent()
        let backup = folder.appending(path: "settings.json.pokove-backup")
        let legacyBackup = folder.appending(path: "settings.json.\(LegacyMigration.legacyName)-backup")
        if fileManager.fileExists(atPath: fileURL.path), !fileManager.fileExists(atPath: backup.path),
           !fileManager.fileExists(atPath: legacyBackup.path) {
            try fileManager.copyItem(at: fileURL, to: backup)
        }
        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: Matching

    private static func isPokove(_ hook: Any) -> Bool {
        guard let hook = hook as? [String: Any] else { return false }
        if let command = hook["command"] as? String {
            return (command.contains("X-Pokove-Host") || command.contains(legacyHeader)) && command.contains(marker)
        }
        if let url = hook["url"] as? String { return url.hasPrefix("http://127.0.0.1:") && url.hasSuffix(marker) }
        return false
    }

    /// The endpoint each pokove hook reports to, for spotting stale ports.
    private static func pokoveURLs(in value: Any?) -> [String] {
        guard let groups = value as? [[String: Any]] else { return [] }
        return groups.flatMap { group in
            (group["hooks"] as? [Any] ?? []).filter(isPokove).compactMap { hook -> String? in
                guard let hook = hook as? [String: Any] else { return nil }
                if let url = hook["url"] as? String { return "legacy:" + url }
                let command = hook["command"] as? String ?? ""
                let url = command.split(separator: " ").first { $0.hasPrefix("http://127.0.0.1:") }.map(String.init)
                // Hooks written under the old name still work, but show as outdated so they get rewritten.
                return command.contains(legacyHeader) ? url.map { "legacy:" + $0 } : url
            }
        }
    }

    /// Returns the event's matcher groups with every pokove hook stripped out.
    private static func removingPokove(from value: Any?) -> [[String: Any]] {
        guard let groups = value as? [[String: Any]] else { return [] }
        return groups.compactMap { group in
            // Groups we don't understand are kept untouched.
            guard let hooks = group["hooks"] as? [Any] else { return group }
            let remaining = hooks.filter { !isPokove($0) }
            if remaining.isEmpty { return remaining.count == hooks.count ? group : nil }
            var group = group
            group["hooks"] = remaining
            return group
        }
    }
}
