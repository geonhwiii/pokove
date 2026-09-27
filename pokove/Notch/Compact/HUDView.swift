import SwiftUI

/// Volume / brightness overlay: the notch stretches into a long bar with the icon and label
/// on one side and the level on the other.
struct HUDView: View {
    let event: HUDEvent
    let layout: NotchLayout

    @Environment(Preferences.self) private var preferences

    private var level: Double { event.isMuted ? 0 : event.value }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: event.kind.symbol(for: event.value, muted: event.isMuted))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20)
                Text(event.kind.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .frame(width: NotchLayout.hudWingWidth)

            Spacer(minLength: layout.notch.width)

            HStack(spacing: 7) {
                LevelBar(value: level, overshoot: event.overshoot, bumpTrigger: event.serial)
                    .frame(height: 6)
                if preferences.hudShowsPercentage {
                    Text("\(Int((level * 100).rounded()))")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                        .contentTransition(.numericText(value: level))
                        .frame(width: 22, alignment: .trailing)
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 13)
            .frame(width: NotchLayout.hudWingWidth)
        }
        .frame(height: layout.notch.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.kind.label)
        .accessibilityValue("\(Int(level * 100)) percent")
    }
}

extension HUDKind {
    var label: String {
        switch self {
        case .volume: String(localized: "Sound")
        case .brightness: String(localized: "Display")
        case .keyboardBacklight: String(localized: "Keyboard")
        }
    }
}

/// A capsule track with a smoothly animated fill and an optional rubber-band bump.
struct LevelBar: View {
    let value: Double
    var tint: Color = .white
    var overshoot: Int = 0
    var bumpTrigger: Int = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.height, proxy.size.width * CGFloat(min(max(value, 0), 1))))
                    .opacity(value <= 0.001 ? 0 : 1)
            }
        }
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bumpTrigger) { content, stretch in
            content.scaleEffect(x: stretch, y: 1 / max(stretch, 1), anchor: overshoot < 0 ? .trailing : .leading)
        } keyframes: { _ in
            if overshoot != 0 {
                SpringKeyframe(1.06, duration: 0.12, spring: .snappy)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            } else {
                MoveKeyframe(1)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: value)
    }
}
