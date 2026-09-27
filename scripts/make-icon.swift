// Renders dancove's app icon into Assets.xcassets/AppIcon.appiconset.
// Run from the repo root: swift scripts/make-icon.swift [preview.png]
//
// A dark bezel like Alcove's around a glossy screen: dusk over a cove, glass waves rolling in,
// and the notch at the top.
import AppKit
import SwiftUI

private func color(_ hex: UInt32, _ opacity: Double = 1) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
          blue: Double(hex & 0xFF) / 255, opacity: opacity)
}

/// The whole icon on Apple's 1024 grid: an 824 pt body with room for its shadow.
struct AppIcon: View {
    var body: some View {
        ZStack {
            Bezel()
            Screen()
                .frame(width: 704, height: 704)
        }
        .frame(width: 1024, height: 1024)
    }
}

private struct Bezel: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 186, style: .continuous)
        ZStack {
            shape
                .fill(LinearGradient(colors: [color(0x2A2A30), color(0x0B0B0E), color(0x050506)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.32), radius: 20, y: 12)
            // A lit top edge, like polished glass.
            shape
                .strokeBorder(LinearGradient(stops: [
                    .init(color: .white.opacity(0.34), location: 0),
                    .init(color: .white.opacity(0.06), location: 0.3),
                    .init(color: .white.opacity(0.02), location: 0.75),
                    .init(color: .white.opacity(0.12), location: 1),
                ], startPoint: .top, endPoint: .bottom), lineWidth: 3)
        }
        .frame(width: 824, height: 824)
    }
}

private struct Screen: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 132, style: .continuous)
        ZStack {
            // Dusk over the cove: deep blue overhead, pink, and a peach glow at the horizon.
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.42], [0.55, 0.4], [1, 0.46],
                    [0, 0.7], [0.5, 0.7], [1, 0.7],
                ],
                colors: [
                    color(0x0A72FF), color(0x3D63FF), color(0x8A5CFF),
                    color(0x6FB6FF), color(0xD58CFF), color(0xFF7FC4),
                    color(0xFFB0C8), color(0xFFD3A6), color(0xFFA68C),
                ]
            )
            // The low sun, just above the water.
            RadialGradient(colors: [.white.opacity(0.95), color(0xFFD9B0, 0.6), color(0xFFB08A, 0)],
                           center: .init(x: 0.5, y: 0.66), startRadius: 0, endRadius: 250)
                .blendMode(.screen)

            GlassWave(baseline: 0.665, amplitude: 0.022, phase: 0.6, periods: 1.3,
                      colors: [color(0x8FDCFF), color(0x4F7BFF), color(0x4A34D8)], glow: 0.75)
            GlassWave(baseline: 0.785, amplitude: 0.03, phase: 2.6, periods: 1.1,
                      colors: [color(0xC4F2FF), color(0x6F9CFF), color(0x6A46F0), color(0x3B25B8)], glow: 1)

            // The sun's path on the water.
            Ellipse()
                .fill(.white.opacity(0.5))
                .frame(width: 70, height: 190)
                .blur(radius: 28)
                .offset(y: 220)
                .blendMode(.screen)

            DarkNotch()
                .frame(maxHeight: .infinity, alignment: .top)

            // Glass sheen: a soft diagonal band of light.
            LinearGradient(stops: [
                .init(color: .white.opacity(0), location: 0.28),
                .init(color: .white.opacity(0.14), location: 0.4),
                .init(color: .white.opacity(0), location: 0.56),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.screen)
        }
        .clipShape(shape)
        // Recessed into the bezel: a soft inner shadow, then a thin bright lip.
        .overlay {
            shape
                .stroke(.black.opacity(0.5), lineWidth: 28)
                .blur(radius: 15)
                .clipShape(shape)
        }
        // Light glowing up from the bottom edge of the glass, as in Alcove's icon.
        .overlay {
            shape
                .stroke(color(0xFFD2F4), lineWidth: 30)
                .blur(radius: 14)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0.7), .init(color: .black, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .clipShape(shape)
                .opacity(0.8)
        }
        .overlay {
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.15), .white.opacity(0.6)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 3)
        }
        .shadow(color: color(0xB08CFF, 0.35), radius: 26)
    }
}

/// A band of water with a sine crest, drawn past the screen's sides and bottom so only the
/// crest shows an edge.
struct WaveShape: Shape {
    var baseline: CGFloat
    var amplitude: CGFloat
    var phase: Double
    var periods: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let overscan: CGFloat = 60
        let steps = 160
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let x = rect.minX - overscan + CGFloat(t) * (rect.width + 2 * overscan)
            let y = rect.minY + rect.height * (baseline + amplitude * CGFloat(sin(t * periods * 2 * .pi + phase)))
            step == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX + overscan, y: rect.maxY + overscan))
        path.addLine(to: CGPoint(x: rect.minX - overscan, y: rect.maxY + overscan))
        path.closeSubpath()
        return path
    }
}

/// Water as thick glass: light caught white along the crest, clear color below.
private struct GlassWave: View {
    let baseline: CGFloat
    let amplitude: CGFloat
    let phase: Double
    let periods: Double
    let colors: [Color]
    let glow: Double

    var body: some View {
        let wave = WaveShape(baseline: baseline, amplitude: amplitude, phase: phase, periods: periods)
        ZStack {
            wave.fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                .opacity(0.82)
            // Cyan light caught just under the crest, as in thick glass.
            wave.stroke(color(0x3FF0FF), lineWidth: 60)
                .blur(radius: 22)
                .opacity(0.55 * glow)
                .mask(wave)
            // The bright inner edge.
            wave.stroke(.white, lineWidth: 26)
                .blur(radius: 10)
                .opacity(0.8 * glow)
                .mask(wave)
            // An iridescent rim along the crest.
            wave.stroke(LinearGradient(colors: [color(0x9DF6FF), .white, color(0xFFB8EC)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 5)
                .blur(radius: 0.8)
                .mask(wave)
        }
        .shadow(color: color(0x2A1C8A, 0.4), radius: 20, y: -6)
    }
}

/// The notch outline the app draws, ears and all: flat top, concave ears, rounded bottom.
struct NotchOutline: Shape {
    var ear: CGFloat = 30
    var radius: CGFloat = 66

    func path(in rect: CGRect) -> Path {
        let left = rect.minX + ear, right = rect.maxX - ear
        let r = min(radius, (right - left) / 2, rect.height - ear)
        let k: CGFloat = 0.55
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.minY + ear), control: CGPoint(x: left, y: rect.minY))
        path.addLine(to: CGPoint(x: left, y: rect.maxY - r))
        path.addCurve(to: CGPoint(x: left + r, y: rect.maxY),
                      control1: CGPoint(x: left, y: rect.maxY - r * (1 - k)), control2: CGPoint(x: left + r * (1 - k), y: rect.maxY))
        path.addLine(to: CGPoint(x: right - r, y: rect.maxY))
        path.addCurve(to: CGPoint(x: right, y: rect.maxY - r),
                      control1: CGPoint(x: right - r * (1 - k), y: rect.maxY), control2: CGPoint(x: right, y: rect.maxY - r * (1 - k)))
        path.addLine(to: CGPoint(x: right, y: rect.minY + ear))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: right, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Glossy black glass, like the real notch, with the screen's colors caught in its rim.
private struct DarkNotch: View {
    var body: some View {
        let shape = NotchOutline(ear: 24, radius: 52)
        ZStack {
            // Light spilling out from under it, like a live activity.
            shape
                .fill(LinearGradient(colors: [color(0x00D8FF), color(0xFF5BD8)], startPoint: .leading, endPoint: .trailing))
                .blur(radius: 36)
                .opacity(0.95)
                .offset(y: 24)
            shape.fill(LinearGradient(colors: [color(0x16161C), color(0x040406)], startPoint: .top, endPoint: .bottom))
            // Reflections pooled in the lower glass.
            shape
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0), location: 0.45),
                    .init(color: color(0x7FD8FF, 0.22), location: 0.8),
                    .init(color: color(0xFF9BE6, 0.3), location: 1),
                ], startPoint: .top, endPoint: .bottom))
            shape
                .stroke(LinearGradient(colors: [color(0x5FE8FF), color(0xB38CFF), color(0xFF8AD8)],
                                       startPoint: .leading, endPoint: .trailing), lineWidth: 7)
                .blur(radius: 1.2)
                .mask(shape)
            Lens()
                .frame(width: 30, height: 30)
                .offset(y: -4)
        }
        .frame(width: 300, height: 100)
    }
}

private struct Lens: View {
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [color(0x3C3FA8), color(0x131437)], center: .init(x: 0.4, y: 0.35),
                                         startRadius: 2, endRadius: 34))
            Circle().strokeBorder(color(0x8C8FFF, 0.6), lineWidth: 3)
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 14, height: 14)
                .blur(radius: 1.5)
                .offset(x: -10, y: -10)
        }
    }
}

// MARK: Output

@MainActor
func render(pixels: Int) -> NSBitmapImageRep {
    let renderer = ImageRenderer(content: AppIcon())
    renderer.scale = CGFloat(pixels) / 1024
    let image = renderer.cgImage!
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: pixels, height: pixels)
    return rep
}

@MainActor
func main() throws {
    if CommandLine.arguments.count > 1 {
        let data = render(pixels: 1024).representation(using: .png, properties: [:])!
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        return
    }
    let output = URL(fileURLWithPath: "dancove/Assets.xcassets/AppIcon.appiconset")
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
            let data = render(pixels: points * scale).representation(using: .png, properties: [:])!
            try data.write(to: output.appending(path: name))
            images.append(["idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)", "filename": name])
        }
    }
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
        .write(to: output.appending(path: "Contents.json"))
    print("Wrote \(images.count) icons to \(output.path)")
}

try MainActor.assumeIsolated { try main() }
