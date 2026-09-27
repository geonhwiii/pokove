import SwiftUI

/// An at-a-glance status of the coding agents, in the calendar's layout: how many are working on
/// the left; on the right, only what's running or waiting for you — or, when all is quiet, today's
/// tally. Individual idle sessions aren't listed.
struct ClaudePageView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let claude = app.claude
        HStack(alignment: .top, spacing: 18) {
            AgentSummary()
                .frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(claude.permissions) { request in
                    PermissionCard(request: request)
                }
                if claude.permissions.isEmpty {
                    let active = claude.activeSessions
                    if active.isEmpty {
                        TodayOverview()
                            .transition(.blurReplace)
                    } else {
                        ForEach(active.prefix(3)) { session in
                            ActiveSessionRow(session: session)
                                .transition(.blurReplace)
                        }
                        if active.count > 3 {
                            Text("+\(active.count - 3) more")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.leading, 38)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: claude.activeSessions.map(\.id))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: claude.permissions)
    }
}

// MARK: Summary

private struct AgentSummary: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let claude = app.claude
        let working = claude.workingSessions.count
        let waiting = claude.attentionSessions.count + (claude.permissions.isEmpty ? 0 : 1)
        let stats = claude.stats
        VStack(alignment: .leading, spacing: 0) {
            Text("Agents")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.claude)
            Text("\(working)")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.bottom, 2)
            Text(caption(working: working, waiting: waiting))
                .font(.system(size: 12))
                .foregroundStyle(waiting > 0 ? Color.claudeAttention : .white.opacity(0.45))
                .contentTransition(.opacity)
            if stats.totalTurns > 0 {
                Text("Today \(stats.totalTurns) · \(ClaudeSessionStore.format(duration: stats.totalSeconds))")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: working)
    }

    private func caption(working: Int, waiting: Int) -> String {
        if waiting > 0 { return String(localized: "\(waiting) waiting") }
        return working > 0 ? String(localized: "working") : String(localized: "All quiet")
    }
}

// MARK: Active sessions

private struct ActiveSessionRow: View {
    let session: ClaudeSession

    @Environment(AppModel.self) private var app
    @State private var isHovering = false

    var body: some View {
        Button {
            app.claude.focus(sessionID: session.id)
        } label: {
            HStack(spacing: 10) {
                AgentMark(agent: session.agent, mode: session.activity.needsAttention ? .attention : .working)
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.displayName)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(session.activity.label)
                        .font(.system(size: 11))
                        .foregroundStyle(session.activity.needsAttention ? Color.claudeAttention : .white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let start = session.turnStartedAt, session.activity.isWorking {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 44, alignment: .trailing)
                } else if session.activity.needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.claudeAttention)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(isHovering ? 0.08 : 0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help(session.projectName)
    }
}

// MARK: Today

/// When nothing is running: what each agent got done today, and the last thing that finished.
private struct TodayOverview: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let stats = app.claude.stats
        let agents: [AgentKind] = app.preferences.watchCodexSessions || stats.turns(for: .codex) > 0 ? [.claude, .codex] : [.claude]
        VStack(alignment: .leading, spacing: 7) {
            Text("Today")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            ForEach(agents, id: \.self) { agent in
                HStack(spacing: 10) {
                    AgentMark(agent: agent)
                        .frame(width: 16, height: 16)
                    Text(agent.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 8)
                    Text(tally(stats, agent))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(stats.turns(for: agent) > 0 ? 0.6 : 0.3))
                }
                .frame(height: 22)
            }
            if let last = stats.lastFinishedSession, let at = stats.lastFinishedAt {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green.opacity(0.8))
                        Text(last)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        Text("· \(ClaudePageView.age(of: at, now: context.date))")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .padding(.top, 2)
            } else {
                Text("Start Claude or Codex anywhere — what they're doing shows up here.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func tally(_ stats: AgentDayStats, _ agent: AgentKind) -> String {
        let turns = stats.turns(for: agent)
        guard turns > 0 else { return "—" }
        return String(localized: "\(turns) turns · \(ClaudeSessionStore.format(duration: stats.seconds(for: agent)))")
    }
}

extension ClaudePageView {
    static func age(of date: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return String(localized: "now") }
        if seconds < 3600 { return String(localized: "\(seconds / 60)m") }
        return String(localized: "\(seconds / 3600)h")
    }
}

private struct PermissionCard: View {
    let request: ClaudePermissionRequest

    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: ClaudeToolDescriber.symbol(for: request.toolName))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.claudeAttention)
                Text("\(app.claude.session(id: request.sessionID)?.projectName ?? "Claude") wants to use \(request.toolName)")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                CountdownRing(start: request.receivedAt, end: request.expiresAt)
                    .frame(width: 14, height: 14)
            }
            Text(request.detail ?? request.summary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Spacer()
                Button("Deny") { app.claude.answer(request.id, with: .deny) }
                    .buttonStyle(NotchPillButtonStyle(kind: .secondary))
                if request.hasSuggestions {
                    Button("Always Allow") { app.claude.answer(request.id, with: .allowAlways) }
                        .buttonStyle(NotchPillButtonStyle(kind: .secondary))
                }
                Button("Allow") { app.claude.answer(request.id, with: .allow) }
                    .buttonStyle(NotchPillButtonStyle(kind: .primary))
            }
        }
        .padding(10)
        .background(Color.claudeAttention.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.claudeAttention.opacity(0.35), lineWidth: 1))
        .transition(.blurReplace)
    }
}
