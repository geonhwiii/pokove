import AppKit
import Observation

/// Tracks every Claude Code session reported through hooks and turns their events into
/// notch activity: a live "working" indicator, banners, and inline permission prompts.
@Observable
final class ClaudeSessionStore {
    private(set) var sessions: [ClaudeSession] = []
    private(set) var permissions: [ClaudePermissionRequest] = []
    private(set) var serverState: ClaudeHookServer.State = .stopped
    private(set) var lastEventAt: Date?
    private(set) var hookStatus: ClaudeHookInstaller.Status = .notInstalled
    /// Finished turns and time spent today, per agent. Resets at midnight.
    private(set) var todayStats = ClaudeSessionStore.loadStats()

    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let adventure: AdventureService
    @ObservationIgnored private var server: ClaudeHookServer?
    @ObservationIgnored private var transcripts: AgentTranscriptWatcher?
    /// Sessions whose hooks said goodbye; late lines in their files must not bring them back.
    @ObservationIgnored private var endedByHooks: [String: Date] = [:]
    @ObservationIgnored private var continuations: [UUID: CheckedContinuation<ClaudeHookServer.Response, Never>] = [:]
    @ObservationIgnored private var finishedResetTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var sweepTimer: Timer?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    static let hookPath = "/claude/hook"

    init(activity: ActivityCenter, preferences: Preferences, adventure: AdventureService) {
        self.activity = activity
        self.preferences = preferences
        self.adventure = adventure
    }

    // MARK: Derived state

    var workingSessions: [ClaudeSession] { sessions.filter { $0.activity.isWorking } }
    /// Sessions working or waiting for the user: what the overview lists.
    var activeSessions: [ClaudeSession] {
        sessions.filter { $0.activity.isWorking || $0.activity.needsAttention }
            .sorted { lhs, rhs in
                if lhs.activity.needsAttention != rhs.activity.needsAttention { return lhs.activity.needsAttention }
                return (lhs.turnStartedAt ?? lhs.updatedAt) < (rhs.turnStartedAt ?? rhs.updatedAt)
            }
    }

    /// Today's numbers, rolled over if the day has changed since they were recorded.
    var stats: AgentDayStats {
        todayStats.day == AgentDayStats.key(for: Date()) ? todayStats : AgentDayStats(day: AgentDayStats.key(for: Date()))
    }
    var attentionSessions: [ClaudeSession] { sessions.filter { $0.activity.needsAttention } }
    var isAnyWorking: Bool { sessions.contains { $0.activity.isWorking } }
    var needsAttention: Bool { !permissions.isEmpty || sessions.contains { $0.activity.needsAttention } }

    /// The session that best represents Claude right now, for the compact indicator.
    var primarySession: ClaudeSession? {
        attentionSessions.max(by: { $0.updatedAt < $1.updatedAt })
            ?? workingSessions.max(by: { $0.updatedAt < $1.updatedAt })
            ?? sessions.max(by: { $0.updatedAt < $1.updatedAt })
    }

    var sortedSessions: [ClaudeSession] {
        sessions.sorted { lhs, rhs in
            if lhs.activity.needsAttention != rhs.activity.needsAttention { return lhs.activity.needsAttention }
            if lhs.activity.isWorking != rhs.activity.isWorking { return lhs.activity.isWorking }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func permission(id: UUID?) -> ClaudePermissionRequest? {
        guard let id else { return nil }
        return permissions.first { $0.id == id }
    }

    func session(id: String?) -> ClaudeSession? {
        guard let id else { return nil }
        return sessions.first { $0.id == id }
    }

    var hookURL: String { "http://127.0.0.1:\(preferences.claudeServerPort)\(Self.hookPath)" }

    // MARK: Hooks

    var installer: ClaudeHookInstaller { ClaudeHookInstaller(port: preferences.claudeServerPort) }

    func refreshHookStatus() {
        hookStatus = installer.status()
    }

    func installHooks() throws {
        defer { refreshHookStatus() }
        try installer.install()
    }

    func uninstallHooks() throws {
        defer { refreshHookStatus() }
        try installer.uninstall()
    }

    // MARK: Lifecycle

    func start() {
        refreshHookStatus()
        guard preferences.claudeEnabled else { return }
        let server = ClaudeHookServer { [weak self] request in
            guard let self else { return .empty }
            return await self.handle(request)
        }
        server.onStateChange = { [weak self] state in self?.serverState = state }
        server.start(port: UInt16(clamping: preferences.claudeServerPort))
        self.server = server

        // Let the notch windows come up first; catching up can add several sessions at once.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self, self.server != nil else { return }
            self.restartWatcher()
        }

        sweepTimer?.invalidate()
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSessionHealth() }
        }

        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
                MainActor.assumeIsolated { self?.hostActivated(bundleID) }
            }
        }
    }

    func stop() {
        resolveAllPermissions()
        adventure.endAllTurns()
        server?.stop()
        server = nil
        transcripts?.stop()
        sweepTimer?.invalidate()
        sweepTimer = nil
        serverState = .stopped
    }

    func restart() {
        stop()
        start()
    }

    /// Applies the session-file detection settings without touching hooks or held requests.
    func restartWatcher() {
        transcripts?.stop()
        guard preferences.claudeEnabled, preferences.watchClaudeSessions || preferences.watchCodexSessions else { return }
        let watcher = transcripts ?? AgentTranscriptWatcher { [weak self] event, headers in
            self?.ingest(event: event, headers: headers)
        }
        transcripts = watcher
        watcher.start(claude: preferences.watchClaudeSessions, codex: preferences.watchCodexSessions)
    }

    // MARK: Actions

    func answer(_ permissionID: UUID, with decision: ClaudePermissionDecision) {
        guard let request = permissions.first(where: { $0.id == permissionID }) else { return }
        var decisionObject: [String: Any]
        switch decision {
        case .allow:
            decisionObject = ["behavior": "allow"]
        case .allowAlways:
            decisionObject = ["behavior": "allow"]
            if let data = request.suggestionsJSON,
               let suggestions = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                decisionObject["updatedPermissions"] = suggestions
            }
        case .deny:
            decisionObject = ["behavior": "deny", "message": "The user denied this from the dancove notch."]
        }
        let response = ClaudeHookServer.Response.json([
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decisionObject,
            ],
        ])
        resolvePermission(permissionID, with: response)
        updateSession(request.sessionID) { session in
            session.activity = decision == .deny ? .thinking : .tool(name: request.toolName, summary: request.summary)
        }
    }

    /// Brings the app hosting a session (terminal, editor, Claude) to the front.
    func focus(sessionID: String?) {
        guard let session = session(id: sessionID) ?? primarySession else { return }
        let bundleID = session.hostBundleID ?? Self.bundleID(forTermProgram: session.termProgram)
        guard let bundleID,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return
        }
        app.activate(from: .current, options: [])
    }

    func clearFinished() {
        sessions.removeAll { $0.activity == .idle || $0.activity == .finished }
        reelInOrphanedLines()
    }

    func remove(sessionID: String) {
        sessions.removeAll { $0.id == sessionID }
        adventure.turnAborted(sessionID: sessionID)
    }

    /// Posts sample events so the integration can be previewed without Claude running.
    func simulateDemo() {
        let id = "demo-\(UUID().uuidString.prefix(6))"
        let cwd = NSHomeDirectory() + "/Projects/dancove"
        ingest(event: ["hook_event_name": "UserPromptSubmit", "session_id": id, "cwd": cwd, "prompt": "Add a notch HUD"], headers: [:])
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            ingest(event: ["hook_event_name": "PreToolUse", "session_id": id, "cwd": cwd, "tool_name": "Edit",
                           "tool_input": ["file_path": cwd + "/NotchView.swift"]], headers: [:])
            try? await Task.sleep(for: .seconds(2.5))
            ingest(event: ["hook_event_name": "PostToolUse", "session_id": id, "cwd": cwd, "tool_name": "Edit"], headers: [:])
            try? await Task.sleep(for: .seconds(1.5))
            ingest(event: ["hook_event_name": "Stop", "session_id": id, "cwd": cwd,
                           "last_assistant_message": "I added a volume HUD that slides out of the notch and matches the system style."], headers: [:])
        }
    }

    // MARK: Hook handling

    private func handle(_ request: ClaudeHookServer.Request) async -> ClaudeHookServer.Response {
        guard request.method == "POST" else {
            return request.method == "GET" && request.path == "/health"
                ? .json(["ok": true, "app": "dancove"])
                : ClaudeHookServer.Response(status: 404)
        }
        guard request.path.hasPrefix(Self.hookPath) else { return ClaudeHookServer.Response(status: 404) }
        // Browsers cannot send JSON cross-origin without a preflight we never answer.
        guard request.headers["content-type"]?.lowercased().hasPrefix("application/json") == true else {
            return ClaudeHookServer.Response(status: 415)
        }
        guard let event = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            return ClaudeHookServer.Response(status: 400)
        }

        if event["hook_event_name"] as? String == "PermissionRequest" {
            return await handlePermissionRequest(event, headers: request.headers)
        }
        ingest(event: event, headers: request.headers)
        return .empty
    }

    private func ingest(event: [String: Any], headers: [String: String]) {
        guard let name = event["hook_event_name"] as? String,
              let sessionID = event["session_id"] as? String else { return }
        let fromTranscript = event["dancove_source"] as? String == "transcript"
        // Session files carry when each step happened; hooks arrive as it happens.
        let now = (event["dancove_timestamp"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        // Hooks report the same Claude sessions more precisely; once they're flowing, they win.
        // Titles only exist in the files, so those still come through.
        if fromTranscript, name != "dancove_title" {
            if let existing = session(id: sessionID), existing.source == .hooks,
               Date().timeIntervalSince(existing.updatedAt) < 30 * 60 {
                return
            }
            if let ended = endedByHooks[sessionID], Date().timeIntervalSince(ended) < 10 * 60 { return }
        }
        lastEventAt = Date()
        // Subagents share the parent session id; only track the main agent's lifecycle.
        let isSubagent = event["agent_id"] != nil

        if name == "SessionEnd" {
            if !fromTranscript { endedByHooks[sessionID] = Date() }
            endSession(sessionID)
            return
        }

        if name == "dancove_title" {
            // Never let a title alone create or revive a session.
            if let title = event["dancove_title"] as? String, !title.isEmpty, session(id: sessionID) != nil {
                updateSession(sessionID) { $0.title = title }
            }
            return
        }
        upsertSession(sessionID, event: event, headers: headers, at: now)
        if name == "dancove_interrupt" {
            // Esc in the Claude app or Codex: the turn ends with nothing to report.
            finishedResetTasks[sessionID]?.cancel()
            updateSession(sessionID) { session in
                session.activity = .idle
                session.turnStartedAt = nil
            }
            adventure.turnAborted(sessionID: sessionID)
            activity.dismissBanners(forSession: sessionID, styles: [.claudeNeedsPermission, .claudeNeedsInput])
            return
        }
        // Previews must not stock the real collection.
        let fishes = !sessionID.hasPrefix("demo-")

        // Progress from the agent that asked means its request was answered elsewhere. Subagents
        // share the session id, so their parallel tool calls must not cancel each other's requests.
        if ["PreToolUse", "PostToolUse", "PostToolUseFailure", "Stop", "SubagentStop", "UserPromptSubmit", "StopFailure"]
            .contains(name) {
            let agentID = event["agent_id"] as? String
            let everyone = name == "UserPromptSubmit" || name == "Stop" || name == "StopFailure"
            for request in permissions where request.sessionID == sessionID && (everyone || request.agentID == agentID) {
                resolvePermission(request.id, with: .empty)
            }
            if agentID == nil {
                activity.dismissBanners(forSession: sessionID, styles: [.claudeNeedsPermission, .claudeNeedsInput])
            }
        }

        switch name {
        case "SessionStart":
            if let model = event["model"] as? String {
                updateSession(sessionID) { $0.model = model }
            }

        case "UserPromptSubmit":
            finishedResetTasks[sessionID]?.cancel()
            updateSession(sessionID) { session in
                session.activity = .thinking
                session.turnStartedAt = now
                session.toolCount = 0
                if let prompt = event["prompt"] as? String { session.lastPrompt = prompt }
            }
            if fishes { adventure.turnStarted(sessionID: sessionID, at: now) }

        case "PreToolUse":
            let tool = event["tool_name"] as? String ?? "Tool"
            let input = event["tool_input"] as? [String: Any] ?? [:]
            updateSession(sessionID) { session in
                if session.turnStartedAt == nil { session.turnStartedAt = now }
                session.activity = .tool(name: tool, summary: ClaudeToolDescriber.summary(tool: tool, input: input))
                session.toolCount += 1
            }
            if fishes {
                // dancove may have launched mid-turn: the main agent's tool call starts the turn.
                if !isSubagent, !adventure.hasTurn(for: sessionID), let start = session(id: sessionID)?.turnStartedAt {
                    adventure.turnStarted(sessionID: sessionID, at: start)
                }
            }

        case "PostToolUse", "PostToolUseFailure", "PostToolBatch":
            updateSession(sessionID) { session in
                if session.activity.isWorking || session.activity.needsAttention { session.activity = .thinking }
            }

        case "SubagentStart":
            updateSession(sessionID) { $0.activeSubagents += 1 }

        case "SubagentStop":
            updateSession(sessionID) { $0.activeSubagents = max(0, $0.activeSubagents - 1) }

        case "PreCompact":
            updateSession(sessionID) { $0.activity = .compacting }

        case "PostCompact":
            updateSession(sessionID) { if $0.activity == .compacting { $0.activity = .thinking } }

        case "Notification":
            handleNotification(event, sessionID: sessionID)

        case "Stop" where !isSubagent:
            let message = event["last_assistant_message"] as? String
            var duration: TimeInterval?
            updateSession(sessionID) { session in
                if let start = session.turnStartedAt { duration = now.timeIntervalSince(start) }
                session.lastTurnDuration = duration
                session.turnStartedAt = nil
                session.activity = .finished
                if let message, !message.isEmpty { session.lastMessage = message }
            }
            scheduleIdle(sessionID)
            if let duration, fishes { recordTurn(sessionID: sessionID, duration: duration, at: now) }
            let caught = fishes ? adventure.turnFinished(sessionID: sessionID, at: now) : nil
            notifyFinished(sessionID: sessionID, message: message, duration: duration, caught: caught)

        case "StopFailure":
            let label = Self.describeFailure(event["error"] as? String)
            adventure.turnAborted(sessionID: sessionID)
            updateSession(sessionID) { session in
                session.activity = .failed(label)
                session.turnStartedAt = nil
            }
            scheduleIdle(sessionID, after: 30)
            if preferences.claudeNotifyOnError, let session = session(id: sessionID) {
                activity.post(NotchBanner(
                    style: .claudeError,
                    title: session.agent == .codex ? String(localized: "Codex stopped") : String(localized: "Claude stopped"),
                    subtitle: session.displayName,
                    detail: label,
                    sessionID: sessionID,
                    agent: session.agent,
                    duration: 6
                ))
            }

        default:
            break
        }
    }

    private func handleNotification(_ event: [String: Any], sessionID: String) {
        let type = event["notification_type"] as? String ?? ""
        let message = event["message"] as? String
        switch type {
        case "permission_prompt":
            // A PermissionRequest hook usually announced this already; only surface it if not.
            guard !permissions.contains(where: { $0.sessionID == sessionID }) else { return }
            updateSession(sessionID) { $0.activity = .needsPermission }
            let agent = session(id: sessionID)?.agent ?? .claude
            postAttention(sessionID: sessionID, style: .claudeNeedsPermission,
                          title: agent == .codex ? String(localized: "Codex needs approval") : String(localized: "Claude needs permission"),
                          detail: message)
        case "idle_prompt":
            // Fires ~60 s after every finished turn; the "finished" banner already covered it.
            break
        case "elicitation_complete", "elicitation_response":
            updateSession(sessionID) { if $0.activity == .needsInput { $0.activity = .thinking } }
            activity.dismissBanners(forSession: sessionID, styles: [.claudeNeedsInput])
        case "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input":
            updateSession(sessionID) { session in
                if !session.activity.isWorking { session.activity = .needsInput }
            }
            postAttention(sessionID: sessionID, style: .claudeNeedsInput, title: String(localized: "Claude is waiting for you"), detail: message)
        case "agent_completed":
            if let message, let session = session(id: sessionID), preferences.claudeNotifyOnDone {
                activity.post(NotchBanner(style: .claudeFinished, title: String(localized: "Background agent finished"),
                                          subtitle: session.displayName, detail: message, sessionID: sessionID,
                                          agent: session.agent))
            }
        default:
            break
        }
    }

    private func handlePermissionRequest(_ event: [String: Any], headers: [String: String]) async -> ClaudeHookServer.Response {
        guard let sessionID = event["session_id"] as? String else { return .empty }
        let now = Date()
        lastEventAt = now
        upsertSession(sessionID, event: event, headers: headers, at: now)

        let tool = event["tool_name"] as? String ?? "Tool"
        let input = event["tool_input"] as? [String: Any] ?? [:]
        let summary = ClaudeToolDescriber.summary(tool: tool, input: input)
        let detail = ClaudeToolDescriber.detail(tool: tool, input: input)
        let suggestions = (event["permission_suggestions"] as? [Any]).flatMap {
            $0.isEmpty ? nil : try? JSONSerialization.data(withJSONObject: $0)
        }
        updateSession(sessionID) { $0.activity = .needsPermission }

        let hold = shouldHoldPermission(for: session(id: sessionID))
        guard preferences.claudeNotifyOnAttention || hold else { return .empty }

        let timeout = max(5, preferences.claudeApprovalTimeout)
        let request = ClaudePermissionRequest(
            id: UUID(),
            sessionID: sessionID,
            agentID: event["agent_id"] as? String,
            toolName: tool,
            summary: summary,
            detail: detail,
            receivedAt: now,
            expiresAt: now.addingTimeInterval(timeout),
            suggestionsJSON: suggestions
        )

        let projectName = session(id: sessionID)?.displayName
        guard hold else {
            // The host app is in front, so its own prompt is visible: just announce it.
            if !(preferences.claudeQuietWhenFocused && isHostFrontmost(session(id: sessionID))) {
                activity.post(NotchBanner(style: .claudeNeedsPermission, title: String(localized: "Claude needs permission"),
                                          subtitle: projectName, detail: detail ?? summary,
                                          sessionID: sessionID, duration: 6))
                playSoundIfNeeded()
            }
            return .empty
        }

        permissions.append(request)
        activity.post(NotchBanner(
            style: .claudeNeedsPermission,
            title: String(localized: "Allow \(tool)?"),
            subtitle: projectName,
            detail: detail ?? summary,
            sessionID: sessionID,
            permissionID: request.id,
            duration: nil
        ))
        playSoundIfNeeded()

        let requestID = request.id
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuations[requestID] = continuation
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(timeout))
                    // Unanswered: fall back to Claude's own prompt.
                    self?.resolvePermission(requestID, with: .empty)
                }
            }
        } onCancel: {
            // Claude closed the connection (Esc, Ctrl-C, its own timeout): drop the prompt.
            Task { @MainActor [weak self] in
                self?.resolvePermission(requestID, with: .empty)
            }
        }
    }

    // MARK: Permission bookkeeping

    private func shouldHoldPermission(for session: ClaudeSession?) -> Bool {
        guard preferences.claudeApproveFromNotch, let session else { return false }
        // Only hold when we know which app shows Claude's own prompt and it isn't in front.
        guard session.hostBundleID != nil || Self.bundleID(forTermProgram: session.termProgram) != nil else { return false }
        return !isHostFrontmost(session)
    }

    private func isHostFrontmost(_ session: ClaudeSession?) -> Bool {
        guard let session else { return false }
        let hostID = session.hostBundleID ?? Self.bundleID(forTermProgram: session.termProgram)
        guard let hostID else { return false }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == hostID
    }

    private func resolvePermission(_ id: UUID, with response: ClaudeHookServer.Response) {
        permissions.removeAll { $0.id == id }
        activity.dismissBanners(forPermission: id)
        continuations.removeValue(forKey: id)?.resume(returning: response)
    }

    /// The user went to the app running Claude: hand the request back so its own prompt shows.
    private func hostActivated(_ bundleID: String?) {
        guard let bundleID else { return }
        for request in permissions {
            guard let session = session(id: request.sessionID) else { continue }
            let host = session.hostBundleID ?? Self.bundleID(forTermProgram: session.termProgram)
            if host == bundleID { resolvePermission(request.id, with: .empty) }
        }
    }

    private func cancelPermissions(forSession sessionID: String) {
        for request in permissions where request.sessionID == sessionID {
            resolvePermission(request.id, with: .empty)
        }
    }

    private func resolveAllPermissions() {
        for request in permissions { resolvePermission(request.id, with: .empty) }
    }

    // MARK: Session bookkeeping

    private func upsertSession(_ id: String, event: [String: Any], headers: [String: String], at date: Date) {
        let cwd = event["cwd"] as? String
        let host = headers["x-dancove-host"].flatMap { $0.isEmpty ? nil : $0 }
            ?? headers["x-dancove-pid"].flatMap(Int32.init).flatMap(Self.hostBundleID(forClaudePID:))
        let term = headers["x-dancove-term"].flatMap { $0.isEmpty ? nil : $0 }
        let pid = headers["x-dancove-pid"].flatMap(Int32.init)
        let fromTranscript = event["dancove_source"] as? String == "transcript"
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            // A hook for a session first seen in its file: hooks take over from here.
            if !fromTranscript { sessions[index].source = .hooks }
            if let cwd { sessions[index].cwd = cwd }
            if let pid { sessions[index].claudePID = pid }
            if let transcript = event["transcript_path"] as? String { sessions[index].transcriptPath = transcript }
            if let host { sessions[index].hostBundleID = host }
            if let term { sessions[index].termProgram = term }
            if let mode = event["permission_mode"] as? String { sessions[index].permissionMode = mode }
            sessions[index].updatedAt = date
        } else {
            var session = ClaudeSession(id: id, cwd: cwd ?? "~", startedAt: date, updatedAt: date)
            session.agent = (event["dancove_agent"] as? String).flatMap(AgentKind.init(rawValue:)) ?? .claude
            session.source = fromTranscript ? .transcript : .hooks
            session.title = event["dancove_title"] as? String
            session.lastMessage = (event["dancove_last_message"] as? String).map(Self.condense)
            session.transcriptPath = event["transcript_path"] as? String
            session.hostBundleID = host
            session.termProgram = term
            session.claudePID = pid
            session.permissionMode = event["permission_mode"] as? String
            sessions.append(session)
        }
    }

    private func updateSession(_ id: String, _ change: (inout ClaudeSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[index])
        sessions[index].updatedAt = Date()
    }

    private func scheduleIdle(_ sessionID: String, after delay: TimeInterval = 8) {
        finishedResetTasks[sessionID]?.cancel()
        finishedResetTasks[sessionID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.updateSession(sessionID) { session in
                if session.activity == .finished || { if case .failed = session.activity { true } else { false } }() {
                    session.activity = .idle
                }
            }
        }
    }

    /// Keeps the list honest when hooks can't: closed terminals, crashes and Esc interrupts
    /// (which fire no `Stop` hook) would otherwise leave sessions stuck as "working".
    private func checkSessionHealth() {
        let now = Date()
        for session in sessions {
            if let pid = session.claudePID, kill(pid, 0) != 0, errno == ESRCH {
                endSession(session.id)
                continue
            }
            // Session files go quiet when the app quits mid-turn or waits on a prompt we can't see.
            if session.source == .transcript, session.activity.isWorking, now.timeIntervalSince(session.updatedAt) > 15 * 60 {
                updateSession(session.id) { session in
                    session.activity = .idle
                    session.turnStartedAt = nil
                }
                adventure.turnAborted(sessionID: session.id)
                continue
            }
            // Esc during a turn, or rejecting Claude's own permission prompt, fires no hook.
            let hasHeldRequest = permissions.contains { $0.sessionID == session.id }
            let mayBeStuck = session.activity.isWorking || (session.activity.needsAttention && !hasHeldRequest)
            if mayBeStuck, now.timeIntervalSince(session.updatedAt) > 5,
               let path = session.transcriptPath, Self.transcriptEndsWithInterrupt(path) {
                updateSession(session.id) { session in
                    session.activity = .idle
                    session.turnStartedAt = nil
                }
                adventure.turnAborted(sessionID: session.id)
            }
        }
        sessions.removeAll { session in
            let age = now.timeIntervalSince(session.updatedAt)
            // A live `claude` process can run one tool for a long time without reporting anything.
            if session.activity.isWorking, let pid = session.claudePID, kill(pid, 0) == 0 { return age > 6 * 60 * 60 }
            if session.activity.isWorking { return age > 2 * 60 * 60 }
            return age > 3 * 60 * 60
        }
        endedByHooks = endedByHooks.filter { now.timeIntervalSince($0.value) < 10 * 60 }
        reelInOrphanedLines()
    }

    /// A turn can't stay open for a session that no longer exists.
    private func reelInOrphanedLines() {
        for sessionID in adventure.turnIDs where session(id: sessionID) == nil {
            #if DEBUG
            if sessionID == "debug" { continue }
            #endif
            adventure.turnAborted(sessionID: sessionID)
        }
    }

    private func endSession(_ sessionID: String) {
        finishedResetTasks[sessionID]?.cancel()
        sessions.removeAll { $0.id == sessionID }
        adventure.turnAborted(sessionID: sessionID)
        cancelPermissions(forSession: sessionID)
        activity.dismissBanners(forSession: sessionID, styles: [.claudeNeedsPermission, .claudeNeedsInput])
    }

    /// Whether the last transcript entry is Claude Code's "[Request interrupted by user]" marker.
    nonisolated static func transcriptEndsWithInterrupt(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path) else { return false }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return false }
        let window: UInt64 = 16 * 1024
        try? handle.seek(toOffset: size > window ? size - window : 0)
        guard let data = try? handle.readToEnd() else { return false }
        // The window may start mid-character; lossy decoding keeps the complete last line intact.
        let text = String(decoding: data, as: UTF8.self)
        guard let last = text.split(whereSeparator: \.isNewline).last(where: { !$0.isEmpty }),
              let object = try? JSONSerialization.jsonObject(with: Data(last.utf8)) as? [String: Any],
              object["type"] as? String == "user",
              let message = object["message"] as? [String: Any] else { return false }
        let content: String
        if let text = message["content"] as? String {
            content = text
        } else if let parts = message["content"] as? [[String: Any]] {
            content = parts.compactMap { $0["text"] as? String }.joined()
        } else {
            return false
        }
        return content.hasPrefix("[Request interrupted by user")
    }

    // MARK: Daily stats

    private func recordTurn(sessionID: String, duration: TimeInterval, at date: Date) {
        guard let session = session(id: sessionID), duration >= 1 else { return }
        var stats = self.stats
        stats.turns[session.agent.rawValue, default: 0] += 1
        stats.seconds[session.agent.rawValue, default: 0] += duration
        stats.lastFinishedSession = session.displayName
        stats.lastFinishedAt = date
        todayStats = stats
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: Self.statsKey)
        }
    }

    private static let statsKey = "agentDayStats"

    private static func loadStats() -> AgentDayStats {
        let today = AgentDayStats.key(for: Date())
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(AgentDayStats.self, from: data),
              stats.day == today else { return AgentDayStats(day: today) }
        return stats
    }

    // MARK: Notifications

    private func notifyFinished(sessionID: String, message: String?, duration: TimeInterval?, caught: PokeEncounter?) {
        let caught = preferences.adventureAnnounceCatches ? caught.flatMap { $0.caught ? $0 : nil } : nil
        defer { if let caught { playCatchSound(for: caught) } }
        guard let session = session(id: sessionID) else { return }
        let quiet = !preferences.claudeNotifyOnDone || (preferences.claudeQuietWhenFocused && isHostFrontmost(session))
        if quiet {
            // Even when "finished" banners are off, a new Pokémon is worth a moment of attention.
            if let caught, caught.isNew, let species = adventure.dex.species(caught.speciesID) {
                var banner = NotchBanner(style: .adventure, title: String(localized: "\(species.name) joined your team!"),
                                         subtitle: session.displayName, sessionID: sessionID, encounter: caught,
                                         duration: caught.isSpecial ? 8 : 5)
                banner.pokemonID = species.id
                activity.post(banner)
            }
            return
        }
        var subtitle = session.displayName
        if let duration, duration >= 1 { subtitle += " · " + Self.format(duration: duration) }
        activity.post(NotchBanner(
            style: .claudeFinished,
            title: session.agent == .codex ? String(localized: "Codex finished") : String(localized: "Claude finished"),
            subtitle: subtitle,
            detail: message.map(Self.condense),
            sessionID: sessionID,
            encounter: caught,
            agent: session.agent,
            duration: caught.map { $0.isSpecial ? 9 : 7 } ?? 5.5
        ))
        playSoundIfNeeded()
    }

    private func playCatchSound(for caught: PokeEncounter) {
        guard preferences.adventureSound, caught.isNew || caught.isSpecial else { return }
        NSSound(named: caught.isSpecial ? "Hero" : "Glass")?.play()
    }

    private func postAttention(sessionID: String, style: NotchBanner.Style, title: String, detail: String?) {
        guard preferences.claudeNotifyOnAttention, let session = session(id: sessionID) else { return }
        if preferences.claudeQuietWhenFocused && isHostFrontmost(session) { return }
        activity.post(NotchBanner(style: style, title: title, subtitle: session.displayName,
                                  detail: detail, sessionID: sessionID, agent: session.agent, duration: 7))
        playSoundIfNeeded()
    }

    private func playSoundIfNeeded() {
        guard preferences.claudePlaySound else { return }
        NSSound(named: "Tink")?.play()
    }

    // MARK: Helpers

    /// Walks from Claude's process to the GUI app responsible for it (Terminal, iTerm, VS Code…).
    nonisolated static func hostBundleID(forClaudePID pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: ResponsibleProcess.pid(for: pid))?.bundleIdentifier
    }

    nonisolated static func bundleID(forTermProgram program: String?) -> String? {
        switch program {
        case "Apple_Terminal": "com.apple.Terminal"
        case "iTerm.app": "com.googlecode.iterm2"
        case "vscode": "com.microsoft.VSCode"
        case "WarpTerminal": "dev.warp.Warp-Stable"
        case "ghostty": "com.mitchellh.ghostty"
        case "WezTerm": "com.github.wez.wezterm"
        case "Hyper": "co.zeit.hyper"
        case "kitty": "net.kovidgoyal.kitty"
        default: nil
        }
    }

    nonisolated static func format(duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        if seconds < 60 { return String(localized: "\(seconds)s") }
        let minutes = seconds / 60
        if minutes < 60 { return String(localized: "\(minutes)m \(seconds % 60)s") }
        return String(localized: "\(minutes / 60)h \(minutes % 60)m")
    }

    nonisolated static func condense(_ text: String) -> String {
        let flattened = text
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[#*`>_]+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return flattened.count > 220 ? String(flattened.prefix(220)) + "…" : flattened
    }

    nonisolated static func describeFailure(_ reason: String?) -> String {
        switch reason {
        case "rate_limit": String(localized: "Rate limited")
        case "overloaded": String(localized: "API overloaded")
        case "authentication_failed": String(localized: "Authentication failed")
        case "billing_error": String(localized: "Billing issue")
        case "server_error": String(localized: "Server error")
        case "max_output_tokens": String(localized: "Hit output limit")
        case "invalid_request": String(localized: "Invalid request")
        case "model_not_found": String(localized: "Model not found")
        case "account_on_hold": String(localized: "Account on hold")
        case "unknown": String(localized: "Something went wrong")
        case let reason?: reason.replacingOccurrences(of: "_", with: " ").capitalized
        case nil: String(localized: "Something went wrong")
        }
    }
}
