import CoreServices
import Foundation

/// Follows the session files Claude Code and Codex write while they work, so dancove sees every
/// session with no setup: the Claude desktop app, the CLI, IDE extensions, and Codex.
///
/// Each appended line becomes a hook-shaped event (`UserPromptSubmit`, `PreToolUse`, `Stop`…)
/// for `ClaudeSessionStore`, so banners, the working indicator and the adventure behave the same as
/// with hooks. Hooks stay optional: they add inline permission answers and win when both report.
final class AgentTranscriptWatcher {
    typealias EventHandler = (_ event: [String: Any], _ headers: [String: String]) -> Void

    struct Roots {
        var claude: URL? = Roots.path("debugClaudeProjectsPath") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        var codex: URL? = Roots.path("debugCodexSessionsPath") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")

        /// Debug builds can point the watcher at scratch folders, so tests never touch real sessions.
        private static func path(_ key: String) -> URL? {
            #if DEBUG
            return UserDefaults.standard.string(forKey: key).map { URL(fileURLWithPath: $0) }
            #else
            return nil
            #endif
        }
    }

    private let onEvent: EventHandler
    private var roots = Roots()
    private var stream: FSEventStreamRef?
    private var files: [String: TranscriptFile] = [:]
    /// Files modified this recently when dancove starts are read to catch sessions already running.
    static let bootstrapWindow: TimeInterval = 20 * 60

    init(onEvent: @escaping EventHandler) {
        self.onEvent = onEvent
    }

    deinit {
        MainActor.assumeIsolated { stop() }
    }

    func start(claude: Bool, codex: Bool) {
        stop()
        let base = Roots()
        // FSEvents reports resolved paths (/private/tmp, a symlinked ~/.claude), so compare those.
        roots = Roots(
            claude: claude ? base.claude.map(Self.canonical) : nil,
            codex: codex ? base.codex.map(Self.canonical) : nil
        )
        let watched = [roots.claude, roots.codex].compactMap { $0 }.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !watched.isEmpty else { return }

        bootstrap()

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            nil,
            transcriptEventsCallback,
            &context,
            watched.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            flags
        ) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        files.values.forEach { $0.cancelPendingStop() }
        files.removeAll()
    }

    // MARK: File events

    fileprivate func pathsChanged(_ paths: [String]) {
        for path in Set(paths) where path.hasSuffix(".jsonl") {
            guard let kind = kind(of: path) else { continue }
            let file = files[path] ?? makeFile(path: path, kind: kind, startAtEnd: false)
            read(file)
        }
    }

    private func kind(of path: String) -> AgentKind? {
        if let claude = roots.claude?.path, path.hasPrefix(claude + "/") { return .claude }
        if let codex = roots.codex?.path, path.hasPrefix(codex + "/"), (path as NSString).lastPathComponent.hasPrefix("rollout-") {
            return .codex
        }
        return nil
    }

    private func makeFile(path: String, kind: AgentKind, startAtEnd: Bool) -> TranscriptFile {
        let file = TranscriptFile(path: path, kind: kind) { [weak self] event in self?.emit(event, from: path) }
        if kind == .codex { file.loadCodexMeta() }
        let size = Self.size(of: path)
        if startAtEnd {
            file.offset = size
        } else if size > 512 * 1024 {
            // A long session seen for the first time: its history is old news, and parsing all of
            // it would be slow. Start near the end; stale lines are dropped by timestamp anyway.
            file.offset = size - 256 * 1024
            file.skipsPartialLine = true
        }
        files[path] = file
        return file
    }

    private func read(_ file: TranscriptFile) {
        let size = Self.size(of: file.path)
        if size < file.offset {
            // Rewritten or truncated: start over.
            file.offset = 0
            file.remainder = Data()
        }
        guard size > file.offset, let handle = FileHandle(forReadingAtPath: file.path) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: file.offset)
        guard let data = try? handle.readToEnd() else { return }
        file.offset += UInt64(data.count)
        file.consume(data, live: true)
    }

    // MARK: Startup

    /// Catches up on sessions that were already running when dancove launched, without replaying
    /// their history as notifications.
    private func bootstrap() {
        let cutoff = Date().addingTimeInterval(-Self.bootstrapWindow)
        var recent: [(url: URL, kind: AgentKind, date: Date)] = []
        if let claude = roots.claude {
            recent += Self.claudeTranscripts(in: claude, since: cutoff).map { ($0.0, .claude, $0.1) }
        }
        if let codex = roots.codex {
            recent += Self.codexTranscripts(in: codex, since: cutoff).map { ($0.0, .codex, $0.1) }
        }
        // Only the most recent handful can plausibly be mid-turn; keep launch light.
        for entry in recent.sorted(by: { $0.date > $1.date }).prefix(12) {
            let file = makeFile(path: entry.url.path, kind: entry.kind, startAtEnd: true)
            file.bootstrap(modifiedAt: entry.date)
        }
    }

    /// `~/.claude/projects/<project>/<session>.jsonl`; subagent files are skipped.
    private static func claudeTranscripts(in root: URL, since cutoff: Date) -> [(URL, Date)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
            return []
        }
        var result: [(URL, Date)] = []
        for project in projects {
            // A folder's date only changes when files are added, not when a transcript grows.
            guard let files = try? fm.contentsOfDirectory(at: project, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else {
                continue
            }
            for file in files where file.pathExtension == "jsonl" && !file.lastPathComponent.hasPrefix("agent-") {
                if let modified = modificationDate(file, keys), modified > cutoff { result.append((file, modified)) }
            }
        }
        return result
    }

    /// `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`, looking only at today and yesterday.
    private static func codexTranscripts(in root: URL, since cutoff: Date) -> [(URL, Date)] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let calendar = Calendar(identifier: .gregorian)
        var result: [(URL, Date)] = []
        for dayOffset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let folder = root.appendingPathComponent(String(format: "%04d/%02d/%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0))
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? []
            for file in files where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
                if let modified = modificationDate(file, keys), modified > cutoff { result.append((file, modified)) }
            }
        }
        return result
    }

    private static func modificationDate(_ url: URL, _ keys: [URLResourceKey]) -> Date? {
        (try? url.resourceValues(forKeys: Set(keys)))?.contentModificationDate
    }

    /// The path FSEvents will report: symlinks resolved, and /private kept (unlike
    /// `resolvingSymlinksInPath`, which strips it from /private/tmp).
    nonisolated private static func canonical(_ url: URL) -> URL {
        guard let resolved = realpath(url.path, nil) else { return url }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }

    private static func size(of path: String) -> UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private static func modificationDate(of path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    // MARK: Emitting

    private func emit(_ event: TranscriptEvent, from path: String) {
        guard let file = files[path], let sessionID = event.sessionID ?? file.sessionID else { return }
        var payload: [String: Any] = [
            "session_id": sessionID,
            "dancove_source": "transcript",
            "dancove_agent": file.kind.rawValue,
            "dancove_timestamp": event.date.timeIntervalSince1970,
        ]
        if let cwd = file.cwd { payload["cwd"] = cwd }
        if file.kind == .claude, !file.isSubagentFile { payload["transcript_path"] = path }

        switch event {
        case .started(_, _, let title, let lastMessage):
            payload["hook_event_name"] = "SessionStart"
            if let title { payload["dancove_title"] = title }
            if let lastMessage { payload["dancove_last_message"] = lastMessage }
        case .prompt(_, _, let text):
            payload["hook_event_name"] = "UserPromptSubmit"
            payload["prompt"] = text
        case .tool(_, _, let name, let input, let isSubagent):
            payload["hook_event_name"] = "PreToolUse"
            payload["tool_name"] = name
            payload["tool_input"] = input
            if isSubagent { payload["agent_id"] = "transcript-subagent" }
        case .toolFinished(_, _, let isSubagent):
            payload["hook_event_name"] = "PostToolUse"
            if isSubagent { payload["agent_id"] = "transcript-subagent" }
        case .finished(_, _, let message):
            payload["hook_event_name"] = "Stop"
            if let message { payload["last_assistant_message"] = message }
        case .interrupted:
            payload["hook_event_name"] = "dancove_interrupt"
        case .failed:
            payload["hook_event_name"] = "StopFailure"
            payload["error"] = "unknown"
        case .needsApproval(_, _, let message):
            payload["hook_event_name"] = "Notification"
            payload["notification_type"] = "permission_prompt"
            if let message { payload["message"] = message }
        case .titled(_, _, let title):
            payload["hook_event_name"] = "dancove_title"
            payload["dancove_title"] = title
        }

        var headers: [String: String] = [:]
        if let host = file.hostBundleID { headers["x-dancove-host"] = host }
        onEvent(payload, headers)
    }
}

/// C callback for the FSEvents stream; forwards the changed paths to the watcher on the main queue.
nonisolated private func transcriptEventsCallback(
    _ stream: ConstFSEventStreamRef,
    _ info: UnsafeMutableRawPointer?,
    _ count: Int,
    _ paths: UnsafeMutableRawPointer,
    _ flags: UnsafePointer<FSEventStreamEventFlags>,
    _ ids: UnsafePointer<FSEventStreamEventId>
) {
    guard let info else { return }
    let watcher = Unmanaged<AgentTranscriptWatcher>.fromOpaque(info).takeUnretainedValue()
    let changed = (Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String]) ?? []
    MainActor.assumeIsolated { watcher.pathsChanged(changed) }
}

// MARK: - Events

/// What happened in a session file, before it's turned into a hook-shaped event.
enum TranscriptEvent {
    case started(sessionID: String?, date: Date, title: String?, lastMessage: String?)
    case prompt(sessionID: String?, date: Date, text: String)
    case tool(sessionID: String?, date: Date, name: String, input: [String: Any], isSubagent: Bool)
    case toolFinished(sessionID: String?, date: Date, isSubagent: Bool)
    case finished(sessionID: String?, date: Date, message: String?)
    case interrupted(sessionID: String?, date: Date)
    case failed(sessionID: String?, date: Date)
    case needsApproval(sessionID: String?, date: Date, message: String?)
    case titled(sessionID: String?, date: Date, title: String)

    var sessionID: String? {
        switch self {
        case .started(let id, _, _, _), .prompt(let id, _, _), .tool(let id, _, _, _, _), .toolFinished(let id, _, _),
             .finished(let id, _, _), .interrupted(let id, _), .failed(let id, _), .needsApproval(let id, _, _),
             .titled(let id, _, _):
            id
        }
    }

    var date: Date {
        switch self {
        case .started(_, let date, _, _), .prompt(_, let date, _), .tool(_, let date, _, _, _), .toolFinished(_, let date, _),
             .finished(_, let date, _), .interrupted(_, let date), .failed(_, let date), .needsApproval(_, let date, _),
             .titled(_, let date, _):
            date
        }
    }
}

// MARK: - One session file

final class TranscriptFile {
    let path: String
    let kind: AgentKind
    var offset: UInt64 = 0
    var remainder = Data()
    /// Set when reading starts mid-file, so the first (partial) line is ignored.
    var skipsPartialLine = false
    /// Lines older than this are history, not something happening now.
    static let freshness: TimeInterval = 10 * 60

    private(set) var sessionID: String?
    private(set) var cwd: String?
    private(set) var hostBundleID: String?
    private(set) var title: String?
    /// Claude writes subagent transcripts beside the session's own file.
    let isSubagentFile: Bool

    private let emit: (TranscriptEvent) -> Void
    /// Claude writes one line per content block of the final message; wait for all of them.
    private var pendingStop: (messageID: String?, date: Date, text: [String])?
    private var stopTask: Task<Void, Never>?
    private var codexLastUserText: String?
    private var announced = false
    /// The newest line handled so far. Some tools re-append old history with its original
    /// timestamps; anything older than this is not news.
    private var highWater = Date.distantPast
    /// Whether a turn has started and not yet finished, as far as this file shows.
    private var turnOpen = false
    /// A slash command only becomes a turn if the model answers it (/compact, /model don't).
    private var pendingCommand: (date: Date, text: String)?
    /// Codex's turn start, held briefly: when Codex imports or replays a thread it writes a whole
    /// turn (started → complete) within milliseconds, and that must not look like work.
    private var pendingCodexTurn: TranscriptEvent?
    private var codexTurnTask: Task<Void, Never>?
    /// A real model turn takes longer than this; anything quicker without tool calls is a replay.
    static let instantTurn: TimeInterval = 1.5

    init(path: String, kind: AgentKind, emit: @escaping (TranscriptEvent) -> Void) {
        self.path = path
        self.kind = kind
        self.emit = emit
        let name = (path as NSString).lastPathComponent
        isSubagentFile = kind == .claude && (name.hasPrefix("agent-") || path.contains("/subagents/"))
        if kind == .claude && !isSubagentFile {
            sessionID = (name as NSString).deletingPathExtension
        }
    }

    func cancelPendingStop() {
        stopTask?.cancel()
        stopTask = nil
        codexTurnTask?.cancel()
        codexTurnTask = nil
    }

    // MARK: Reading

    func consume(_ data: Data, live: Bool) {
        var buffer = remainder
        buffer.append(data)
        if skipsPartialLine, let newline = buffer.firstIndex(of: 0x0A) {
            skipsPartialLine = false
            buffer = Data(buffer[buffer.index(after: newline)...])
        }
        var lines: [Data] = []
        var start = buffer.startIndex
        while let newline = buffer[start...].firstIndex(of: 0x0A) {
            lines.append(buffer[start..<newline])
            start = buffer.index(after: newline)
        }
        remainder = Data(buffer[start...])
        for line in lines where !line.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            for event in parse(object) { handle(event, live: live) }
        }
    }

    /// Reads the tail of a file that was active before launch and reports only where it stands now.
    func bootstrap(modifiedAt: Date, window: UInt64 = 128 * 1024) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > window ? size - window : 0)
        guard var data = try? handle.readToEnd() else { return }
        if size > window, let newline = data.firstIndex(of: 0x0A) {
            // The window starts mid-line; drop the fragment.
            data = Data(data[data.index(after: newline)...])
        }
        // A line still being written stays buffered, so its end completes it on the next read.
        var complete = data
        remainder = Data()
        if let last = data.last, last != 0x0A {
            if let newline = data.lastIndex(of: 0x0A) {
                complete = Data(data[..<newline])
                remainder = Data(data[data.index(after: newline)...])
            } else {
                complete = Data()
                remainder = data
            }
        }

        var events: [TranscriptEvent] = []
        for line in complete.split(separator: 0x0A) {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            events.append(contentsOf: parse(object))
        }
        // Tool results with screenshots can fill the whole window with a single line; look further.
        if events.isEmpty, size > window, window < 2 * 1024 * 1024 {
            bootstrap(modifiedAt: modifiedAt, window: window * 4)
            return
        }
        offset = size
        highWater = events.map(\.date).max() ?? highWater

        var turnStart: Date?
        var promptText = ""
        var lastTool: TranscriptEvent?
        var lastMessage: String?
        var working = false
        var turnHadTool = false
        var realTurns = 0
        for event in events {
            switch event {
            case .prompt(_, let date, let text):
                working = true
                turnStart = date
                promptText = text
                lastTool = nil
                turnHadTool = false
            case .tool(_, let date, _, _, let isSubagent):
                // The prompt may be further back than the window; tool calls mean a turn is on.
                if !working { turnStart = date }
                working = true
                turnHadTool = true
                if !isSubagent { lastTool = event }
            case .toolFinished(_, let date, false):
                if !working { turnStart = date }
                working = true
                turnHadTool = true
                lastTool = nil
            case .finished(_, let date, let message):
                let instant = !turnHadTool && turnStart.map { date.timeIntervalSince($0) < Self.instantTurn } ?? false
                if !instant { realTurns += 1 }
                working = false
                lastMessage = message ?? lastMessage
            case .interrupted, .failed:
                working = false
            default:
                break
            }
        }
        // Still nothing readable, but the file is being written to right now: that's a turn in progress.
        if events.isEmpty, Date().timeIntervalSince(modifiedAt) < 90 {
            working = true
            turnStart = modifiedAt
        }
        guard !isSubagentFile, sessionID != nil else { return }
        // A Codex file holding only replayed turns (an import) is not a session the user ran.
        if kind == .codex && realTurns == 0 && !working { return }
        announce(date: modifiedAt, lastMessage: lastMessage)
        // Only a session touched in the last few minutes can really still be mid-turn.
        if working, Date().timeIntervalSince(modifiedAt) < 5 * 60 {
            turnOpen = true
            emit(.prompt(sessionID: sessionID, date: turnStart ?? modifiedAt, text: promptText))
            if let lastTool { emit(lastTool) }
        }
    }

    private func announce(date: Date, lastMessage: String? = nil) {
        guard !announced, !isSubagentFile, sessionID != nil else { return }
        announced = true
        emit(.started(sessionID: sessionID, date: date, title: title, lastMessage: lastMessage))
    }

    private func handle(_ event: TranscriptEvent, live: Bool) {
        guard live, Date().timeIntervalSince(event.date) < Self.freshness,
              event.date >= highWater.addingTimeInterval(-2) else { return }
        highWater = max(highWater, event.date)

        if kind == .codex {
            switch event {
            case .prompt:
                // Hold the start until the turn proves to be real work.
                pendingCodexTurn = event
                codexTurnTask?.cancel()
                codexTurnTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(Self.instantTurn))
                    guard !Task.isCancelled else { return }
                    self?.releaseCodexTurn()
                }
                return
            case .finished, .interrupted:
                if pendingCodexTurn != nil {
                    // Started and finished at once with nothing in between: replayed history.
                    codexTurnTask?.cancel()
                    pendingCodexTurn = nil
                    return
                }
            case .tool, .toolFinished, .needsApproval, .failed:
                releaseCodexTurn()
            default:
                break
            }
        }
        if !isSubagentFile { announce(date: event.date) }

        switch event {
        case .prompt:
            pendingCommand = nil
            flushStop()
            turnOpen = true
            emit(event)
            return
        case .tool(_, let date, _, _, false), .toolFinished(_, let date, false), .finished(_, let date, _):
            if !turnOpen {
                // The model is answering without a prompt we counted (a slash command, or a turn
                // that started before this file was followed): the turn starts here.
                turnOpen = true
                let command = pendingCommand
                pendingCommand = nil
                emit(.prompt(sessionID: sessionID, date: command?.date ?? date, text: command?.text ?? ""))
            }
        case .interrupted, .failed:
            turnOpen = false
            pendingCommand = nil
        default:
            break
        }

        if case .finished(_, let date, let message) = event, kind == .claude {
            // Merge the blocks of one final message; flush once the writes settle.
            if pendingStop == nil { pendingStop = (nil, date, []) }
            if let message, !message.isEmpty { pendingStop?.text.append(message) }
            stopTask?.cancel()
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                self?.flushStop()
            }
            return
        }
        if case .tool(_, _, _, _, false) = event {
            // Claude kept going after an "end_turn" block: that wasn't the end of the turn.
            stopTask?.cancel()
            pendingStop = nil
        }
        emit(event)
    }

    private func releaseCodexTurn() {
        codexTurnTask?.cancel()
        codexTurnTask = nil
        guard let turn = pendingCodexTurn else { return }
        pendingCodexTurn = nil
        announce(date: turn.date)
        turnOpen = true
        emit(turn)
    }

    private func flushStop() {
        stopTask?.cancel()
        stopTask = nil
        guard let pending = pendingStop else { return }
        pendingStop = nil
        turnOpen = false
        let text = pending.text.joined(separator: "\n")
        emit(.finished(sessionID: sessionID, date: pending.date, message: text.isEmpty ? nil : text))
    }

    // MARK: Parsing

    private func parse(_ object: [String: Any]) -> [TranscriptEvent] {
        switch kind {
        case .claude: parseClaude(object)
        case .codex: parseCodex(object)
        }
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func date(_ value: Any?) -> Date {
        guard let text = value as? String else { return Date() }
        return isoFormatter.date(from: text) ?? ISO8601DateFormatter().date(from: text) ?? Date()
    }

    private func parseClaude(_ object: [String: Any]) -> [TranscriptEvent] {
        let type = object["type"] as? String
        if type == "custom-title", let title = object["customTitle"] as? String, !title.isEmpty {
            self.title = title
            return [.titled(sessionID: sessionID, date: Date(), title: title)]
        }
        guard type == "user" || type == "assistant" else { return [] }
        if sessionID == nil { sessionID = object["sessionId"] as? String }
        if let cwd = object["cwd"] as? String { self.cwd = cwd }
        if hostBundleID == nil { hostBundleID = Self.claudeHost(entrypoint: object["entrypoint"] as? String) }

        let date = Self.date(object["timestamp"])
        let subagent = isSubagentFile || object["isSidechain"] as? Bool == true
        guard let message = object["message"] as? [String: Any] else { return [] }

        if type == "user" {
            if object["isMeta"] as? Bool == true || object["isCompactSummary"] as? Bool == true { return [] }
            let text: String
            if let string = message["content"] as? String {
                text = string
            } else if let parts = message["content"] as? [[String: Any]] {
                if parts.contains(where: { $0["type"] as? String == "tool_result" }) {
                    return [.toolFinished(sessionID: sessionID, date: date, isSubagent: subagent)]
                }
                text = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
            } else {
                return []
            }
            if text.hasPrefix("[Request interrupted by user") { return subagent ? [] : [.interrupted(sessionID: sessionID, date: date)] }
            // Local commands (/cost, /clear…) print output without running the model.
            if subagent || text.hasPrefix("<local-command") || text.isEmpty { return [] }
            if text.hasPrefix("<command-name>") || text.hasPrefix("<command-message>") {
                // Only a turn if the model answers; see `handle`.
                pendingCommand = (date, text)
                return []
            }
            return [.prompt(sessionID: sessionID, date: date, text: text)]
        }

        var events: [TranscriptEvent] = []
        let parts = message["content"] as? [[String: Any]] ?? []
        for part in parts where part["type"] as? String == "tool_use" {
            events.append(.tool(
                sessionID: sessionID,
                date: date,
                name: part["name"] as? String ?? "Tool",
                input: part["input"] as? [String: Any] ?? [:],
                isSubagent: subagent
            ))
        }
        if !subagent, let stop = message["stop_reason"] as? String, ["end_turn", "stop_sequence", "max_tokens"].contains(stop) {
            let text = parts.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined(separator: "\n")
            events.append(.finished(sessionID: sessionID, date: date, message: text))
        }
        return events
    }

    private static func claudeHost(entrypoint: String?) -> String? {
        switch entrypoint {
        case "claude-desktop": "com.anthropic.claudefordesktop"
        case "claude-vscode": "com.microsoft.VSCode"
        default: nil
        }
    }

    // MARK: Codex

    /// Codex names the session in its first line; later lines don't repeat it.
    func loadCodexMeta() {
        guard kind == .codex, let handle = FileHandle(forReadingAtPath: path) else { return }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 256 * 1024),
              let newline = head.firstIndex(of: 0x0A),
              let object = try? JSONSerialization.jsonObject(with: head[head.startIndex..<newline]) as? [String: Any] else { return }
        _ = parseCodex(object)
    }

    private func parseCodex(_ object: [String: Any]) -> [TranscriptEvent] {
        let date = Self.date(object["timestamp"])
        let payload = object["payload"] as? [String: Any] ?? [:]
        let payloadType = payload["type"] as? String

        switch object["type"] as? String {
        case "session_meta":
            sessionID = payload["id"] as? String ?? payload["session_id"] as? String ?? sessionID
            cwd = payload["cwd"] as? String ?? cwd
            hostBundleID = Self.codexHost(originator: payload["originator"] as? String)
            if let sessionID { title = Self.codexThreadName(for: sessionID) }
            return []

        case "event_msg":
            switch payloadType {
            case "task_started":
                var events: [TranscriptEvent] = []
                // Codex names a thread after its first turn; pick the name up when it appears.
                if title == nil, let sessionID, let name = Self.codexThreadName(for: sessionID) {
                    title = name
                    events.append(.titled(sessionID: sessionID, date: date, title: name))
                }
                events.append(.prompt(sessionID: sessionID, date: date, text: codexLastUserText ?? ""))
                return events
            case "user_message":
                codexLastUserText = payload["message"] as? String
                return []
            case "task_complete":
                return [.finished(sessionID: sessionID, date: date, message: payload["last_agent_message"] as? String)]
            case "turn_aborted":
                return [.interrupted(sessionID: sessionID, date: date)]
            case "exec_approval_request", "apply_patch_approval_request", "request_permissions":
                return [.needsApproval(sessionID: sessionID, date: date, message: payload["reason"] as? String)]
            case "error":
                return [.failed(sessionID: sessionID, date: date)]
            default:
                return []
            }

        case "response_item":
            switch payloadType {
            case "function_call", "custom_tool_call", "local_shell_call", "web_search_call":
                let (name, input) = Self.codexTool(payload)
                return [.tool(sessionID: sessionID, date: date, name: name, input: input, isSubagent: false)]
            case "function_call_output", "custom_tool_call_output":
                return [.toolFinished(sessionID: sessionID, date: date, isSubagent: false)]
            case "message" where payload["role"] as? String == "user":
                let parts = payload["content"] as? [[String: Any]] ?? []
                let text = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
                // Codex injects its environment context as a user message; skip those.
                if !text.isEmpty && !text.hasPrefix("<") { codexLastUserText = text }
                return []
            default:
                return []
            }

        default:
            return []
        }
    }

    private static func codexHost(originator: String?) -> String? {
        guard let originator = originator?.lowercased() else { return nil }
        if originator.contains("desktop") { return "com.openai.codex" }
        if originator.contains("vscode") { return "com.microsoft.VSCode" }
        return nil
    }

    /// Maps Codex tool calls onto the Claude tool names the describer understands.
    private static func codexTool(_ payload: [String: Any]) -> (String, [String: Any]) {
        let name = payload["name"] as? String ?? payload["type"] as? String ?? "Tool"
        var arguments: [String: Any] = [:]
        if let json = payload["arguments"] as? String, let data = json.data(using: .utf8) {
            arguments = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        // Built-in calls carry their details in `action` instead of `arguments`.
        if let action = payload["action"] as? [String: Any] {
            arguments.merge(action) { current, _ in current }
        }
        switch name {
        case "update_plan":
            return ("TodoWrite", [:])
        case "view_image":
            return ("Read", (arguments["path"] as? String).map { ["file_path": $0] } ?? [:])
        case "shell", "exec_command", "local_shell_call", "shell_command", "exec":
            let command: String
            if let parts = arguments["command"] as? [String] {
                command = parts.count >= 3 && parts[1] == "-lc" ? parts[2] : parts.joined(separator: " ")
            } else {
                command = arguments["command"] as? String ?? arguments["cmd"] as? String ?? ""
            }
            return ("Bash", ["command": command])
        case "apply_patch":
            let patch = payload["input"] as? String ?? ""
            let file = patch.split(separator: "\n")
                .first { $0.hasPrefix("*** Update File: ") || $0.hasPrefix("*** Add File: ") }
                .map { String($0.split(separator: ":", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces) }
            return ("Edit", file.map { ["file_path": $0] } ?? [:])
        case "web_search", "web_search_call":
            let query = arguments["query"] as? String ?? ""
            return ("WebSearch", query.isEmpty ? [:] : ["query": query])
        default:
            return (name, arguments)
        }
    }

    private static var indexCache: (modified: Date, text: String)?

    /// Codex keeps thread titles in `~/.codex/session_index.jsonl` (read once per change).
    private static func codexThreadName(for id: String) -> String? {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/session_index.jsonl")
        guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return nil }
        let text: String
        if let cache = indexCache, cache.modified == modified {
            text = cache.text
        } else {
            guard let fresh = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            indexCache = (modified, fresh)
            text = fresh
        }
        var name: String?
        for line in text.split(separator: "\n") where line.contains(id) {
            if let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
               object["id"] as? String == id {
                name = object["thread_name"] as? String ?? name
            }
        }
        return name
    }
}
