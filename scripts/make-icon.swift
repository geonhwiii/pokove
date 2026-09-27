// Renders pokove's app icon into Assets.xcassets/AppIcon.appiconset.
// Run from the repo root: swift scripts/make-icon.swift [preview.png]
//
// A dark bezel like Alcove's around a pixel-art screen: dusk over a cove, drawn on a 44-cell grid
// like a GBA scene, with the notch at the top, a stardust sparkle and a sail on the horizon.
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

/// The pixel scene behind glass: scaled up without smoothing, with a faint sheen and a recessed edge.
private struct Screen: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 132, style: .continuous)
        Image(decorative: CoveScene().draw().image(), scale: 1)
            .interpolation(.none)
            .resizable()
            .overlay {
                LinearGradient(stops: [
                    .init(color: .white.opacity(0), location: 0.3),
                    .init(color: .white.opacity(0.1), location: 0.42),
                    .init(color: .white.opacity(0), location: 0.54),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.screen)
            }
            .clipShape(shape)
            .overlay {
                shape.stroke(.black.opacity(0.45), lineWidth: 24).blur(radius: 12).clipShape(shape)
            }
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.12), .white.opacity(0.5)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 3)
            }
            .shadow(color: color(0xB08CFF, 0.3), radius: 24)
    }
}

// MARK: Pixel scene

/// A square grid of sRGB colors; empty cells stay transparent.
private struct PixelGrid {
    let size: Int
    private var cells: [UInt32?]

    init(size: Int) {
        self.size = size
        cells = Array(repeating: nil, count: size * size)
    }

    subscript(x: Int, y: Int) -> UInt32? {
        get { x >= 0 && y >= 0 && x < size && y < size ? cells[y * size + x] : nil }
        set { if x >= 0 && y >= 0 && x < size && y < size { cells[y * size + x] = newValue } }
    }

    func image() -> CGImage {
        var bytes = [UInt8](repeating: 0, count: size * size * 4)
        for (i, cell) in cells.enumerated() {
            guard let cell else { continue }
            bytes[i * 4] = UInt8((cell >> 16) & 0xFF)
            bytes[i * 4 + 1] = UInt8((cell >> 8) & 0xFF)
            bytes[i * 4 + 2] = UInt8(cell & 0xFF)
            bytes[i * 4 + 3] = 255
        }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: CGDataProvider(data: Data(bytes) as CFData)!,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}

/// Dusk over the cove on a 44-cell grid.
private struct CoveScene {
    let size = 44
    let horizon = 29                 // first row of water
    let sunRadius = 6.6
    let notchWidth = 18, notchHeight = 5

    /// Deep blue overhead down to a peach glow at the horizon.
    let sky: [UInt32] = [0x2446E0, 0x3D5CFF, 0x6A5CFF, 0x9A5EF6, 0xCB68EC, 0xFF7FC4, 0xFFA2B6, 0xFFCBA8]
    let stars: [(x: Int, y: Int, bright: Bool)] = [(5, 4, true), (12, 11, false), (39, 15, false), (4, 17, false)]
    let sparkle = (x: 34, y: 9)
    let sail = (x: 9, y: 29)

    func draw() -> PixelGrid {
        var grid = PixelGrid(size: size)
        drawSky(into: &grid)
        drawSun(into: &grid)
        drawSail(into: &grid)
        drawSea(into: &grid)
        drawSparkles(into: &grid)
        drawNotch(into: &grid)
        return grid
    }

    /// Flat bands, thinner toward the horizon, with one checkered row between each pair.
    private func drawSky(into grid: inout PixelGrid) {
        let bounds = (1..<sky.count).map { i in
            Int((Double(horizon) * (1 - pow(1 - Double(i) / Double(sky.count), 1.35))).rounded())
        }
        for y in 0..<horizon {
            let band = bounds.firstIndex { y < $0 } ?? bounds.count
            for x in 0..<size {
                let dithered = band < bounds.count && y == bounds[band] - 1 && (x + y) % 2 == 0
                grid[x, y] = sky[dithered ? band + 1 : band]
            }
        }
    }

    /// A half disc sitting on the horizon, white at its core.
    private func drawSun(into grid: inout PixelGrid) {
        let center = Double(size) / 2
        for y in 0..<horizon {
            for x in 0..<size {
                let dx = Double(x) + 0.5 - center, dy = Double(y) + 0.5 - Double(horizon)
                let distance = (dx * dx + dy * dy).squareRoot()
                if distance <= sunRadius { grid[x, y] = distance <= sunRadius * 0.58 ? 0xFFFFFF : 0xFFF1C9 }
            }
        }
    }

    /// A small sail standing on the horizon.
    private func drawSail(into grid: inout PixelGrid) {
        for (i, width) in [1, 1, 2, 2, 3].enumerated() {
            for x in sail.x..<(sail.x + width) { grid[x, sail.y - 5 + i] = 0xFFF6EE }
        }
    }

    /// The front wave's crest row at column `x`.
    private func frontCrest(_ x: Int) -> Int {
        Int((Double(size) * (0.815 + 0.022 * sin(Double(x) / Double(size) * 1.15 * 2 * .pi + 2.4))).rounded())
    }

    private func drawSea(into grid: inout PixelGrid) {
        let crest: UInt32 = 0xC8F4FF, crestDim: UInt32 = 0x8FDCFF
        for x in 0..<size {
            let front = frontCrest(x)
            for y in horizon..<size {
                let cell: UInt32
                if y == horizon { cell = crestDim }
                else if y < front { cell = y < horizon + (front - horizon) / 2 ? 0x5A86FF : 0x5A48EC }
                else if y == front { cell = crest }
                else if y == front + 1 { cell = crestDim }
                else { cell = y >= size - 3 ? 0x2A1C8A : 0x3A26B8 }
                grid[x, y] = cell
            }
        }
        // The sun's path on the water: dashes that shrink toward the front wave.
        let mid = size / 2
        for (i, y) in stride(from: horizon + 1, to: frontCrest(mid) - 1, by: 2).enumerated() {
            let half = max(1, Int((sunRadius * (1.05 - 0.28 * Double(i))).rounded()))
            let inset = i % 2
            for x in (mid - half + inset)..<(mid + half - inset) where grid[x, y] != crest {
                grid[x, y] = i == 0 ? 0xFFE3C4 : 0xE9D8FF
            }
        }
    }

    private func drawSparkles(into grid: inout PixelGrid) {
        for star in stars { grid[star.x, star.y] = star.bright ? 0xFFFFFF : 0xBFC8FF }
        // A four-point stardust glint.
        grid[sparkle.x, sparkle.y] = 0xFFFFFF
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] { grid[sparkle.x + dx, sparkle.y + dy] = 0xBFC8FF }
        for (dx, dy) in [(-2, 0), (2, 0), (0, -2), (0, 2)] { grid[sparkle.x + dx, sparkle.y + dy] = 0x8FA0FF }
    }

    /// The notch with its ears, a camera lens, and a live activity's light spilling out below.
    private func drawNotch(into grid: inout PixelGrid) {
        let left = (size - notchWidth) / 2, right = left + notchWidth - 1
        for y in 0..<notchHeight {
            for x in left...right where !(y == notchHeight - 1 && (x == left || x == right)) {
                grid[x, y] = 0x000000
            }
        }
        grid[left - 1, 0] = 0x000000
        grid[right + 1, 0] = 0x000000
        let lensX = size / 2 - 1, lensY = notchHeight / 2 - 1
        grid[lensX, lensY] = 0x9A9DFF
        grid[lensX + 1, lensY] = 0x2B2E8C
        grid[lensX, lensY + 1] = 0x2B2E8C
        grid[lensX + 1, lensY + 1] = 0x2B2E8C
        let glow: [UInt32] = [0x49E6FF, 0x6FC8FF, 0x9AA8FF, 0xC792FF, 0xF08AE0, 0xFF7FD0]
        for x in (left + 1)...(right - 1) {
            let t = Double(x - left - 1) / Double(right - left - 2)
            grid[x, notchHeight] = glow[min(glow.count - 1, Int(t * Double(glow.count)))]
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
    let output = URL(fileURLWithPath: "pokove/Assets.xcassets/AppIcon.appiconset")
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
