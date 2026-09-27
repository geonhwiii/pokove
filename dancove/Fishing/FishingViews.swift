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

extension FishRarity {
    var color: Color { Color(hex: hex) }

    /// Prismatic colors for mythic items, drifting over time.
    static func prism(at time: TimeInterval, count: Int = 4) -> [Color] {
        (0..<count).map { index in
            let hue = (time * 0.18 + Double(index) / Double(count) * 0.55).truncatingRemainder(dividingBy: 1)
            return Color(hue: hue, saturation: 0.62, brightness: 1)
        }
    }
}

/// Rendered sprites, cached: a sprite never changes, and the grid redraws often.
enum SpriteCache {
    private static var images: [String: CGImage] = [:]

    static func image(_ key: String, sprite: PixelSprite, silhouette: Bool = false) -> CGImage? {
        let cacheKey = silhouette ? key + "#silhouette" : key
        if let image = images[cacheKey] { return image }
        let image = sprite.makeImage(silhouette: silhouette ? 0xFFFFFF : nil)
        images[cacheKey] = image
        return image
    }
}

/// A sprite scaled by whole device pixels with nearest-neighbor sampling, so every dot stays crisp.
struct PixelImage: View {
    let key: String
    let sprite: PixelSprite
    /// Points per sprite pixel. Use multiples of 0.5 so each pixel maps to whole Retina pixels.
    var pixelSize: CGFloat = 2
    var silhouette = false

    var body: some View {
        if let image = SpriteCache.image(key, sprite: sprite, silhouette: silhouette) {
            Image(decorative: image, scale: 1)
                .interpolation(.none)
                .resizable()
                .frame(width: CGFloat(image.width) * pixelSize, height: CGFloat(image.height) * pixelSize)
        }
    }
}

struct FishSpriteView: View {
    let species: FishSpecies
    var pixelSize: CGFloat = 2
    var silhouette = false

    var body: some View {
        PixelImage(key: species.id, sprite: species.sprite, pixelSize: pixelSize, silhouette: silhouette)
            .accessibilityLabel(silhouette ? Text("Unknown fish") : Text(species.name))
    }
}

/// The rarity name in its color; Mythic shimmers through the spectrum.
struct RarityLabel: View {
    let rarity: FishRarity
    var size: CGFloat = 10

    var body: some View {
        let text = Text(rarity.title).font(.system(size: size, weight: .heavy))
        if rarity == .mythic {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                text.foregroundStyle(LinearGradient(
                    colors: FishRarity.prism(at: context.date.timeIntervalSinceReferenceDate),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            }
        } else {
            text.foregroundStyle(rarity.color)
        }
    }
}

/// A soft glow behind a sprite in its rarity's color; Mythic cycles hues.
struct RarityAura: View {
    let rarity: FishRarity
    var intensity: Double = 1
    /// Keep within half the frame's shorter side so the glow never shows an edge.
    var radius: CGFloat = 44

    var body: some View {
        if rarity == .mythic {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                let colors = FishRarity.prism(at: context.date.timeIntervalSinceReferenceDate, count: 3)
                RadialGradient(
                    colors: [colors[0].opacity(0.55 * intensity), colors[1].opacity(0.22 * intensity), .clear],
                    center: .center, startRadius: 2, endRadius: radius
                )
            }
        } else {
            RadialGradient(
                colors: [rarity.color.opacity(0.4 * intensity), rarity.color.opacity(0.12 * intensity), .clear],
                center: .center, startRadius: 2, endRadius: radius
            )
        }
    }
}

/// Four-point pixel stars that twinkle around a celebrated catch.
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

/// The red-and-white float. It rides the swell and ducks under when a tool call nibbles.
struct BobberView: View {
    let nibbleTick: Int
    var pixelSize: CGFloat = 1.5
    var showsWater = true

    @State private var nibbleAt: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let sinceNibble = nibbleAt.map { context.date.timeIntervalSince($0) } ?? .infinity
            let dip = sinceNibble < 0.6 ? sin(min(1, sinceNibble / 0.6) * .pi) * 3 : 0
            let bob = (sin(time * 2.6) * 1.2 * 2).rounded() / 2
            ZStack(alignment: .bottom) {
                PixelImage(key: "bobber", sprite: FishingArt.bobber, pixelSize: pixelSize)
                    .offset(y: -pixelSize * 2 + bob + dip)
                if showsWater {
                    // Drawn over the float, so a nibble pulls it under the surface.
                    WaterLine(time: time, pixel: pixelSize, splash: sinceNibble < 0.5)
                        .frame(height: pixelSize * 3)
                }
            }
        }
        .onChange(of: nibbleTick) { nibbleAt = Date() }
        .accessibilityLabel(Text("Fishing"))
    }
}

/// A strip of pixel waves.
private struct WaterLine: View {
    let time: TimeInterval
    let pixel: CGFloat
    var splash = false

    var body: some View {
        Canvas { canvas, size in
            let columns = Int(size.width / pixel)
            let shift = Int(time * 6)
            for column in 0..<columns {
                let crest = (column + shift) % 5 < 2
                let rect = CGRect(x: CGFloat(column) * pixel, y: crest ? 0 : pixel, width: pixel, height: pixel)
                canvas.fill(Path(rect), with: .color(Color(hex: crest ? 0x8FD0FF : 0x3E8EE0)))
                canvas.fill(Path(CGRect(x: rect.minX, y: pixel * 2, width: pixel, height: pixel)), with: .color(Color(hex: 0x1E4E9A)))
            }
            if splash {
                let center = columns / 2
                for dx in [-3, 3, -4, 4] {
                    let rect = CGRect(x: CGFloat(center + dx) * pixel, y: 0, width: pixel, height: pixel)
                    canvas.fill(Path(rect), with: .color(.white))
                }
            }
        }
    }
}
