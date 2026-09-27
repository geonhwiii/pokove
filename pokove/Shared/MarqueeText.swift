import SwiftUI

/// Single-line text that scrolls when it doesn't fit, with softly faded edges.
struct MarqueeText: View {
    let text: String
    var symbol: String? = nil
    var font: Font = .system(size: 12, weight: .medium)
    var color: Color = .white
    var speed: Double = 32
    var gap: CGFloat = 36

    @State private var textWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let overflows = textWidth > proxy.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !overflows || reduceMotion)) { context in
                let cycle = textWidth + gap
                // Hold still for a beat before each loop so the start is readable.
                let raw = context.date.timeIntervalSinceReferenceDate * speed
                let period = cycle + speed * 1.2
                let position = raw.truncatingRemainder(dividingBy: period)
                let offset = overflows && !reduceMotion ? -max(0, position - speed * 1.2) : 0

                HStack(spacing: gap) {
                    label
                    if overflows { label }
                }
                .offset(x: offset)
                .frame(width: proxy.size.width, alignment: overflows ? .leading : .center)
            }
            .mask {
                if overflows {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.08),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                } else {
                    Rectangle()
                }
            }
        }
        .clipped()
        .accessibilityLabel(text)
    }

    private var label: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(font)
                    .imageScale(.small)
                    .foregroundStyle(color.opacity(0.6))
            }
            Text(text)
                .font(font)
                .foregroundStyle(color)
        }
        .lineLimit(1)
        .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
    }
}
