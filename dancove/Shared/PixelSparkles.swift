import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Four-point pixel stars that twinkle around a celebrated moment.
struct PixelSparkles: View {
    var color: Color
    var count = 9
    var prismatic = false
    var pixel: CGFloat = 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for index in 0..<count {
                    // Deterministic scatter so sparkles don't jump between frames.
                    let seed = Double(index) * 12.9898
                    let x = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let y = (sin(seed * 1.7) * 24634.6345).truncatingRemainder(dividingBy: 1)
                    let phase = (time * 1.6 + Double(index) * 0.37).truncatingRemainder(dividingBy: 1)
                    guard phase < 0.7 else { continue }
                    let point = CGPoint(x: abs(x) * size.width, y: abs(y) * size.height)
                    let big = phase > 0.2 && phase < 0.5
                    let tint = prismatic
                        ? Color(hue: (time * 0.2 + Double(index) * 0.13).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 1)
                        : color
                    let cells: [(Int, Int)] = big ? [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)] : [(0, 0)]
                    for (dx, dy) in cells {
                        let rect = CGRect(
                            x: (point.x / pixel).rounded() * pixel + CGFloat(dx) * pixel,
                            y: (point.y / pixel).rounded() * pixel + CGFloat(dy) * pixel,
                            width: pixel, height: pixel
                        )
                        canvas.fill(Path(rect), with: .color(dx == 0 && dy == 0 ? .white : tint))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
