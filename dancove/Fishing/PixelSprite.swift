import CoreGraphics
import Foundation

/// A small pixel-art image written as rows of characters, so every pixel stays a deliberate choice.
///
/// Body pixels (`#`) are shaded automatically from one consistent light direction and every shape
/// gets the same 1 px outline, which keeps a whole collection of sprites stylistically uniform.
///
/// | char | meaning |
/// |------|---------|
/// | `.`  | transparent |
/// | `#`  | body, auto-shaded into `B` (back / shadow), `M` (mid), `L` (belly / light), `H` (highlight) |
/// | `B` `M` `L` `H` | force a ramp color |
/// | `g`  | a darker body line (gills, scales); same color as `B` |
/// | `f` `F` | fin, dark fin |
/// | `e` `p` | eye white, pupil |
/// | `a` `b` `c` `d` | pattern colors |
/// | `o`  | outline color, drawn inside the shape |
/// | `~` `+` `*` | colors that never get an outline: tentacles, legs, glows, sparkles |
nonisolated struct PixelSprite: Sendable {
    enum Shading: Sendable {
        /// Dark back, light belly: countershaded fish.
        case fish
        /// Lit from the top-left: shells, boots, jellyfish bells.
        case lit
        /// No automatic shading.
        case flat
    }

    let rows: [String]
    let palette: [Character: UInt32]
    var shading: Shading = .fish
    /// Collection sprites share one canvas; small UI sprites (the bobber) render tight.
    var padsToCanvas = true

    /// Every sprite renders onto the same canvas so they share one pixel scale.
    static let canvasWidth = 24
    static let canvasHeight = 16

    private static let unoutlined: Set<Character> = ["o", "~", "+", "*"]
    private static let bodyParts: Set<Character> = ["#", "B", "M", "L", "H", "g", "e", "p", "a", "b", "c", "d"]
    private static let sharedPalette: [Character: UInt32] = [
        "e": 0xF4F2EA,
        "p": 0x141418,
        "w": 0xF7F5EF,
        "k": 0x1B1B22,
    ]

    /// Resolves the sprite into colors (0xRRGGBB, or nil for transparent) on the shared canvas.
    func pixels() -> [[UInt32?]] {
        let grid = rows.map(Array.init)
        let height = grid.count
        let width = grid.map(\.count).max() ?? 0
        func char(_ x: Int, _ y: Int) -> Character {
            guard y >= 0, y < height, x >= 0, x < grid[y].count else { return "." }
            return grid[y][x]
        }

        let colors = resolvedPalette()
        let bodyXs = (0..<height).flatMap { y in (0..<width).filter { Self.bodyParts.contains(char($0, y)) } }
        let bodyMinX = bodyXs.min() ?? 0
        let bodyMaxX = bodyXs.max() ?? 0

        // Shape pixels, padded by one on every side to leave room for the outline.
        var shape = [[UInt32?]](repeating: [UInt32?](repeating: nil, count: width + 2), count: height + 2)
        var solid = [[Bool]](repeating: [Bool](repeating: false, count: width + 2), count: height + 2)
        for y in 0..<height {
            for x in 0..<width {
                let c = char(x, y)
                guard c != "." && c != " " else { continue }
                let key = c == "#" ? shade(x: x, y: y, char: char, bodyMinX: bodyMinX, bodyMaxX: bodyMaxX) : c
                shape[y + 1][x + 1] = colors[key] ?? colors["M"] ?? 0xFF00FF
                solid[y + 1][x + 1] = !Self.unoutlined.contains(c)
            }
        }

        let outline = colors["o"] ?? 0x101014
        var result = shape
        for y in 0..<(height + 2) {
            for x in 0..<(width + 2) where shape[y][x] == nil {
                let touches = [(0, -1), (0, 1), (-1, 0), (1, 0)].contains { dx, dy in
                    let nx = x + dx, ny = y + dy
                    return ny >= 0 && ny < height + 2 && nx >= 0 && nx < width + 2 && solid[ny][nx]
                }
                if touches { result[y][x] = outline }
            }
        }

        // Center on the shared canvas.
        let canvasW = padsToCanvas ? max(Self.canvasWidth, width + 2) : width + 2
        let canvasH = padsToCanvas ? max(Self.canvasHeight, height + 2) : height + 2
        let offsetX = (canvasW - (width + 2)) / 2
        let offsetY = (canvasH - (height + 2)) / 2
        var canvas = [[UInt32?]](repeating: [UInt32?](repeating: nil, count: canvasW), count: canvasH)
        for y in 0..<(height + 2) {
            for x in 0..<(width + 2) {
                canvas[y + offsetY][x + offsetX] = result[y][x]
            }
        }
        return canvas
    }

    /// Picks a ramp color for an auto-shaded body pixel from where it sits in its column and row.
    private func shade(x: Int, y: Int, char: (Int, Int) -> Character, bodyMinX: Int, bodyMaxX: Int) -> Character {
        func isBody(_ x: Int, _ y: Int) -> Bool { Self.bodyParts.contains(char(x, y)) }
        var top = y, bottom = y
        while isBody(x, top - 1) { top -= 1 }
        while isBody(x, bottom + 1) { bottom += 1 }
        var left = x, right = x
        while isBody(left - 1, y) { left -= 1 }
        while isBody(right + 1, y) { right += 1 }

        let span = bottom - top + 1
        let rel = span > 1 ? Double(y - top) / Double(span - 1) : 0.5
        let relX = right > left ? Double(x - left) / Double(right - left) : 0.5

        switch shading {
        case .flat:
            return "M"
        case .fish:
            guard span >= 3 else { return "M" }
            // A short glint along the upper front, where top-left light catches the head.
            let bodyWidth = max(1, bodyMaxX - bodyMinX)
            let front = Double(x - bodyMinX) / Double(bodyWidth)
            if span >= 5 && y == top + 1 && front > 0.12 && front < 0.4 { return "H" }
            if rel < 0.3 { return "B" }
            if rel > 0.7 { return "L" }
            return "M"
        case .lit:
            let score = 0.65 * rel + 0.35 * relX
            if span >= 4 && score < 0.12 { return "H" }
            if score < 0.32 { return "L" }
            if score > 0.7 { return "B" }
            return "M"
        }
    }

    private func resolvedPalette() -> [Character: UInt32] {
        var colors = Self.sharedPalette.merging(palette) { _, sprite in sprite }
        let mid = colors["M"] ?? 0x888888
        if colors["B"] == nil { colors["B"] = Self.mix(mid, 0x101830, 0.4) }
        if colors["L"] == nil { colors["L"] = Self.mix(mid, 0xFFF4D8, 0.45) }
        if colors["H"] == nil { colors["H"] = Self.mix(colors["L"]!, 0xFFFFFF, 0.55) }
        if colors["g"] == nil { colors["g"] = colors["B"] }
        if colors["o"] == nil {
            // Hue-shifted toward blue, but light enough to read on the notch's pure black.
            colors["o"] = Self.mix(colors["B"]!, 0x0A0A1E, 0.55)
        }
        if colors["f"] == nil { colors["f"] = colors["B"] }
        if colors["F"] == nil { colors["F"] = Self.mix(colors["f"]!, 0x0A0A1E, 0.35) }
        return colors
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ value: UInt32, _ shift: UInt32) -> Double { Double((value >> shift) & 0xFF) }
        func blend(_ shift: UInt32) -> UInt32 {
            UInt32((channel(a, shift) * (1 - t) + channel(b, shift) * t).rounded()) << shift
        }
        return blend(16) | blend(8) | blend(0)
    }

    // MARK: Rendering

    /// Renders one image pixel per sprite pixel; scale it up with nearest-neighbor sampling.
    func makeImage(silhouette: UInt32? = nil, silhouetteAlpha: Double = 1) -> CGImage? {
        Self.makeImage(from: pixels(), silhouette: silhouette, silhouetteAlpha: silhouetteAlpha)
    }

    static func makeImage(from pixels: [[UInt32?]], silhouette: UInt32? = nil, silhouetteAlpha: Double = 1) -> CGImage? {
        let height = pixels.count
        let width = pixels.first?.count ?? 0
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                guard let color = pixels[y][x] else { continue }
                let value = silhouette ?? color
                let alpha = silhouette == nil ? 1.0 : silhouetteAlpha
                let index = (y * width + x) * 4
                // Premultiplied RGBA.
                bytes[index] = UInt8(Double((value >> 16) & 0xFF) * alpha)
                bytes[index + 1] = UInt8(Double((value >> 8) & 0xFF) * alpha)
                bytes[index + 2] = UInt8(Double(value & 0xFF) * alpha)
                bytes[index + 3] = UInt8(255 * alpha)
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
