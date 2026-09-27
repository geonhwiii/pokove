import Foundation

/// What a Claude Code session is doing right now, derived from hook events.
enum ClaudeActivity: Equatable {
    case idle
    case thinking
    case tool(name: String, summary: String)
    case compacting
    case needsPermission
    case needsInput
    case finished
    case failed(String)

    var isWorking: Bool {
        switch self {
        case .thinking, .tool, .compacting: true
        default: false
        }
    }

    var needsAttention: Bool {
        switch self {
        case .needsPermission, .needsInput: true
        default: false
        }
    }

    var label: String {
        switch self {
        case .idle: String(localized: "Idle")
        case .thinking: String(localized: "Thinking…")
        case .tool(_, let summary): summary
        case .compacting: String(localized: "Compacting context…")
        case .needsPermission: String(localized: "Needs permission")
        case .needsInput: String(localized: "Waiting for you")
        case .finished: String(localized: "Done")
        case .failed(let reason): reason
        }
    }
}

/// The coding agent behind a session.
nonisolated enum AgentKind: String, Sendable {
    case claude
    case codex

    /// "Claude" / "Codex", for titles like "Claude finished".
    var name: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        }
    }

    /// The product label shown at the top of banners.
    var product: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }
}

/// Where dancove learns about a session. Hooks are precise and can answer permission requests;
/// session files need no setup and also cover the Claude app, IDEs and Codex.
nonisolated enum SessionSource: Sendable {
    case hooks
    case transcript
}

struct ClaudeSession: Identifiable, Equatable {
    let id: String
    var agent: AgentKind = .claude
    var source: SessionSource = .hooks
    /// The app's own name for the conversation, when it has one.
    var title: String?
    var cwd: String
    var transcriptPath: String?
    var activity: ClaudeActivity = .idle
    var lastPrompt: String?
    var lastMessage: String?
    var permissionMode: String?
    var model: String?
    /// Bundle identifier of the app that hosts the session (Terminal, iTerm, VS Code, Claude…).
    var hostBundleID: String?
    var termProgram: String?
    /// PID of the `claude` process, used to notice sessions whose terminal was closed.
    var claudePID: Int32?
    var startedAt: Date
    var updatedAt: Date
    var turnStartedAt: Date?
    var lastTurnDuration: TimeInterval?
    var activeSubagents = 0
    var toolCount = 0

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    /// The conversation's title when the app named it, otherwise the project folder.
    var displayName: String {
        guard let title, !title.isEmpty else { return projectName }
        return title
    }
}

/// What the agents got done today, for the Claude page's overview.
nonisolated struct AgentDayStats: Codable, Equatable, Sendable {
    var day: String
    var turns: [String: Int] = [:]
    var seconds: [String: Double] = [:]
    var lastFinishedSession: String?
    var lastFinishedAt: Date?

    func turns(for agent: AgentKind) -> Int { turns[agent.rawValue] ?? 0 }
    func seconds(for agent: AgentKind) -> TimeInterval { seconds[agent.rawValue] ?? 0 }
    var totalTurns: Int { turns.values.reduce(0, +) }
    var totalSeconds: TimeInterval { seconds.values.reduce(0, +) }

    static func key(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// A `PermissionRequest` hook the notch is holding open so it can be answered inline.
struct ClaudePermissionRequest: Identifiable, Equatable {
    let id: UUID
    let sessionID: String
    /// Set when a subagent asked; subagents share their parent's session id.
    let agentID: String?
    let toolName: String
    let summary: String
    let detail: String?
    let receivedAt: Date
    let expiresAt: Date
    /// Raw `permission_suggestions` entries, echoed back for "Always allow".
    let suggestionsJSON: Data?

    var hasSuggestions: Bool { suggestionsJSON != nil }
}

enum ClaudePermissionDecision {
    case allow
    case allowAlways
    case deny
}

/// Turns tool calls into short, human-readable descriptions.
nonisolated enum ClaudeToolDescriber {
    static func summary(tool: String, input: [String: Any]) -> String {
        func file(_ key: String = "file_path") -> String? {
            (input[key] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
        }
        switch tool {
        case "Bash":
            if let description = input["description"] as? String, !description.isEmpty { return description }
            return firstLine(input["command"] as? String) ?? String(localized: "Running command")
        case "Read":
            return file().map { String(localized: "Reading \($0)") } ?? String(localized: "Reading")
        case "Edit", "MultiEdit":
            return file().map { String(localized: "Editing \($0)") } ?? String(localized: "Editing")
        case "Write":
            return file().map { String(localized: "Writing \($0)") } ?? String(localized: "Writing")
        case "NotebookEdit":
            return file("notebook_path").map { String(localized: "Editing \($0)") } ?? String(localized: "Editing notebook")
        case "Grep":
            return (input["pattern"] as? String).map { String(localized: "Searching “\($0)”") } ?? String(localized: "Searching")
        case "Glob":
            return (input["pattern"] as? String).map { String(localized: "Finding \($0)") } ?? String(localized: "Finding files")
        case "WebFetch":
            if let url = (input["url"] as? String).flatMap(URL.init(string:)), let host = url.host() {
                return String(localized: "Fetching \(host)")
            }
            return String(localized: "Fetching")
        case "WebSearch":
            return (input["query"] as? String).map { String(localized: "Searching web: \($0)") } ?? String(localized: "Searching web")
        case "Task", "Agent":
            return (input["description"] as? String).map { String(localized: "Agent: \($0)") } ?? String(localized: "Running agent")
        case "TodoWrite", "TaskCreate", "TaskUpdate":
            return String(localized: "Updating tasks")
        default:
            if tool.hasPrefix("mcp__") {
                let parts = tool.split(separator: "_", omittingEmptySubsequences: true)
                if parts.count >= 3 {
                    return "\(parts[1]) · \(parts.dropFirst(2).joined(separator: "_"))"
                }
            }
            return tool
        }
    }

    static func detail(tool: String, input: [String: Any]) -> String? {
        switch tool {
        case "Bash":
            return input["command"] as? String
        case "Read", "Edit", "MultiEdit", "Write":
            return input["file_path"] as? String
        case "WebFetch":
            return input["url"] as? String
        default:
            return nil
        }
    }

    static func symbol(for tool: String) -> String {
        switch tool {
        case "Bash": "terminal"
        case "Read": "doc.text"
        case "Edit", "MultiEdit", "Write", "NotebookEdit": "pencil"
        case "Grep", "Glob": "magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Task", "Agent": "person.2"
        default: "wrench.and.screwdriver"
        }
    }

    private static func firstLine(_ text: String?) -> String? {
        guard let text else { return nil }
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return line.count > 80 ? String(line.prefix(80)) + "…" : line
    }
}
