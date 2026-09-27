import SwiftUI

extension Color {
    /// The periwinkle at the heart of Codex's gradient, for tints and badges.
    static let codex = Color(red: 0.48, green: 0.55, blue: 1.0)
}

/// The soft eight-lobed cloud of the Codex app icon.
struct CodexCloudShape: Shape {
    var lobes = 8
    var depth: CGFloat = 0.065

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        let steps = 160
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi - .pi / 2
            let r = radius * (1 - depth + depth * CGFloat(cos(Double(lobes) * angle)))
            let point = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Codex's mark: the gradient cloud with a `>_` prompt. While Codex works the cloud turns and the
/// cursor blinks; it pulses when Codex needs you.
struct CodexMark: View {
    var mode: ClaudeMark.Mode = .still
    /// A flat color instead of the gradient (errors).
    var tint: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let gradient = LinearGradient(
        colors: [Color(red: 0.8, green: 0.72, blue: 1.0), Color(red: 0.48, green: 0.55, blue: 1.0), Color(red: 0.23, green: 0.32, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: mode == .still || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                CodexCloudShape()
                    .fill(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(Self.gradient))
                    .rotationEffect(.degrees(mode == .working && !reduceMotion ? time.truncatingRemainder(dividingBy: 9) * 40 : 0))
                PromptGlyph(cursorVisible: mode != .working || reduceMotion || sin(time * 7) > -0.2)
                    .padding(.horizontal, 0)
            }
            .scaleEffect(mode == .attention && !reduceMotion ? 0.88 + 0.12 * CGFloat(abs(sin(time * 4))) : 1)
        }
        .accessibilityLabel(Text("Codex"))
    }
}

/// The white `>_` inside the Codex cloud.
private struct PromptGlyph: View {
    let cursorVisible: Bool

    var body: some View {
        Canvas { canvas, size in
            let side = min(size.width, size.height)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * side, y: origin.y + y * side) }
            let line = side * 0.1
            var chevron = Path()
            chevron.move(to: point(0.3, 0.35))
            chevron.addLine(to: point(0.44, 0.5))
            chevron.addLine(to: point(0.3, 0.65))
            canvas.stroke(chevron, with: .color(.white), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            if cursorVisible {
                var cursor = Path()
                cursor.move(to: point(0.53, 0.64))
                cursor.addLine(to: point(0.71, 0.64))
                canvas.stroke(cursor, with: .color(.white), style: StrokeStyle(lineWidth: line, lineCap: .round))
            }
        }
    }
}

/// The right mark for a session's agent.
struct AgentMark: View {
    let agent: AgentKind
    var mode: ClaudeMark.Mode = .still
    /// Overrides the agent's own color (errors, dimmed rows).
    var color: Color?

    var body: some View {
        switch agent {
        case .claude: ClaudeMark(mode: mode, color: color ?? .claude)
        case .codex: CodexMark(mode: mode, tint: color)
        }
    }
}

extension AgentKind {
    var color: Color {
        switch self {
        case .claude: .claude
        case .codex: .codex
        }
    }
}
