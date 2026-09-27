import SwiftUI

/// Animated equalizer bars. Driven by layered sine waves rather than real audio, which
/// would require screen-capture permission; it only animates while playback is running.
struct AudioVisualizer: View {
    var isPlaying: Bool
    var color: Color = .white
    var barCount = 4
    var spacing: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isPlaying || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let barWidth = (size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
                // Alcove tints bars with a vertical gradient of the artwork's colors.
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [color, color.opacity(0.65)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
                for index in 0..<barCount {
                    let height = max(barWidth, size.height * level(index, time))
                    let rect = CGRect(
                        x: CGFloat(index) * (barWidth + spacing),
                        y: (size.height - height) / 2,
                        width: barWidth,
                        height: height
                    )
                    canvas.fill(Capsule().path(in: rect), with: shading)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func level(_ index: Int, _ time: TimeInterval) -> CGFloat {
        guard isPlaying, !reduceMotion else { return 0.22 }
        let seed = Double(index) * 1.7
        let value = 0.5
            + 0.28 * sin(time * (5.1 + seed * 0.9) + seed)
            + 0.18 * sin(time * (8.3 + seed * 0.4) + seed * 2.3)
            + 0.08 * sin(time * 13.7 + seed * 4.1)
        return CGFloat(min(max(value, 0.18), 1))
    }
}

#Preview {
    AudioVisualizer(isPlaying: true, color: .pink)
        .frame(width: 20, height: 16)
        .padding()
        .background(.black)
}
