import SwiftUI

/// Content for a closed notch with a live activity: one view per side of the camera housing.
struct CompactActivityView: View {
    let activity: CompactActivity
    let layout: NotchLayout
    let wingWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: wingWidth, height: layout.notch.height)
            Spacer(minLength: layout.notch.width)
            trailing
                .frame(width: wingWidth, height: layout.notch.height)
        }
        .frame(height: layout.notch.height)
    }

    @ViewBuilder private var leading: some View {
        switch activity {
        case .media, .mediaAndClaude: MediaCompactLeading(height: layout.notch.height)
        case .claudeWorking: ClaudeCompactLeading(mode: .working, height: layout.notch.height)
        case .claudeAttention: ClaudeCompactLeading(mode: .attention, height: layout.notch.height)
        case .charging: ChargingCompactLeading()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch activity {
        case .media: MediaCompactTrailing(showsClaude: false)
        case .mediaAndClaude: MediaCompactTrailing(showsClaude: true)
        case .claudeWorking: ClaudeCompactTrailing(attention: false)
        case .claudeAttention: ClaudeCompactTrailing(attention: true)
        case .charging: ChargingCompactTrailing()
        }
    }
}

// MARK: Media

private struct MediaCompactLeading: View {
    let height: CGFloat
    @Environment(AppModel.self) private var app

    var body: some View {
        let side = max(16, height - 12)
        ArtworkView(image: app.nowPlaying.artwork, cornerRadius: side * 0.26)
            .frame(width: side, height: side)
            .scaleEffect(app.nowPlaying.isPlaying ? 1 : 0.86)
            .opacity(app.nowPlaying.isPlaying ? 1 : 0.7)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: app.nowPlaying.isPlaying)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
    }
}

private struct MediaCompactTrailing: View {
    let showsClaude: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        let media = app.nowPlaying
        let tint = app.preferences.tintWithArtwork ? Color(nsColor: media.accentColor) : .white
        HStack(spacing: 7) {
            if showsClaude {
                AgentMark(agent: app.claude.workingSessions.first?.agent ?? .claude, mode: .working)
                    .frame(width: 13, height: 13)
                    .transition(.scale.combined(with: .opacity))
            }
            visualizer(media: media, tint: tint)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 10)
    }

    @ViewBuilder
    private func visualizer(media: NowPlayingService, tint: Color) -> some View {
        Group {
            if app.preferences.showVisualizer {
                AudioVisualizer(isPlaying: media.isPlaying, color: tint)
                    .frame(width: 18, height: 14)
            } else {
                Image(systemName: media.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }
}

// MARK: Claude

private struct ClaudeCompactLeading: View {
    let mode: ClaudeMark.Mode
    let height: CGFloat

    @Environment(AppModel.self) private var app

    var body: some View {
        AgentMark(agent: app.claude.primarySession?.agent ?? .claude, mode: mode)
            .frame(width: height - 14, height: height - 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 9)
    }
}

private struct ClaudeCompactTrailing: View {
    let attention: Bool
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if attention {
                Image(systemName: app.claude.permissions.isEmpty ? "ellipsis.bubble.fill" : "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.claudeAttention)
                    .symbolEffect(.pulse, options: .repeating)
            } else if let start = app.claude.primarySession?.turnStartedAt {
                HStack(spacing: 5) {
                    if app.adventure.isEnabled, let leader = app.adventure.leader {
                        // The partner battles alongside while the agent works.
                        PartnerIcon(speciesID: leader.speciesID)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                ThinkingDots()
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 9)
    }
}

/// Three dots that ripple while Claude thinks.
struct ThinkingDots: View {
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(color)
                        .frame(width: 3.5, height: 3.5)
                        .opacity(0.35 + 0.65 * max(0, sin(time * 5 - Double(index) * 0.8)))
                }
            }
        }
    }
}

// MARK: Charging

private struct ChargingCompactLeading: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("Charging")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 10)
    }
}

private struct ChargingCompactTrailing: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 6) {
            Text("\(app.battery.level)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            BatteryGlyph(level: app.battery.level, isCharging: true)
                .frame(width: 25, height: 12)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 10)
    }
}

/// A battery outline filled to the current level, colored like the system indicator.
struct BatteryGlyph: View {
    let level: Int
    var isCharging = false
    var isLowPower = false

    private var fillColor: Color {
        if isLowPower { return .yellow }
        if isCharging { return .green }
        return level <= 20 ? .red : .white
    }

    var body: some View {
        GeometryReader { proxy in
            let capWidth = proxy.size.width * 0.07
            let bodyWidth = proxy.size.width - capWidth - 1
            HStack(spacing: 1) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: proxy.size.height * 0.3, style: .continuous)
                        .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                    RoundedRectangle(cornerRadius: proxy.size.height * 0.18, style: .continuous)
                        .fill(fillColor)
                        .frame(width: max(2, (bodyWidth - 4) * CGFloat(level) / 100))
                        .padding(2)
                        .animation(.smooth, value: level)
                }
                .frame(width: bodyWidth)
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.45))
                    .frame(width: capWidth, height: proxy.size.height * 0.36)
            }
        }
        .accessibilityLabel("Battery \(level) percent")
    }
}
