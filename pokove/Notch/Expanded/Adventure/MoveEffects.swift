import SwiftUI

/// One move's visual: a projectile for special moves, then a burst in the move type's style.
struct MoveEffect: Identifiable, Equatable {
    let id = UUID()
    let type: PokeType
    let physical: Bool
    let from: CGPoint
    let to: CGPoint
    let start: Date
    let strong: Bool

    /// Special moves travel first; physical ones land right after the lunge.
    var travel: Double { physical ? 0.12 : 0.28 }
    var duration: Double { travel + 0.55 }
}

/// Pixel particles for moves, drawn on one canvas while any effect is alive.
struct MoveEffectsLayer: View {
    let effects: [MoveEffect]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 45, paused: effects.isEmpty)) { context in
            Canvas { canvas, _ in
                for effect in effects {
                    let t = context.date.timeIntervalSince(effect.start)
                    guard t >= 0, t <= effect.duration else { continue }
                    MoveEffectPainter(effect: effect).draw(in: &canvas, at: t)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MoveEffectPainter {
    let effect: MoveEffect

    private enum Style { case flame, splash, bolt, leaf, shards, rings, bubbles, gust, impact, debris }

    private var style: Style {
        switch effect.type {
        case .fire, .dragon: .flame
        case .water: .splash
        case .electric: .bolt
        case .grass, .bug: .leaf
        case .ice, .steel: .shards
        case .psychic, .ghost, .fairy: .rings
        case .poison: .bubbles
        case .flying: .gust
        case .ground, .rock: .debris
        case .normal, .fighting, .dark: .impact
        }
    }

    private var palette: [Color] {
        let base = Color(hex: effect.type.hex)
        return switch effect.type {
        case .fire: [Color(hex: 0xFFD04A), Color(hex: 0xFF7A1A), Color(hex: 0xE83A14)]
        case .water: [Color(hex: 0xBFE6FF), Color(hex: 0x5AA8FF), Color(hex: 0x2D6BE0)]
        case .electric: [.white, Color(hex: 0xFFF06A), Color(hex: 0xF7C21C)]
        case .grass: [Color(hex: 0xB8F07A), Color(hex: 0x6CC04A), Color(hex: 0x3E8A2E)]
        case .ice: [.white, Color(hex: 0xC8F4F4), Color(hex: 0x7ED0E0)]
        case .psychic: [Color(hex: 0xFFC0DA), Color(hex: 0xF95587), Color(hex: 0xC03A70)]
        case .ghost: [Color(hex: 0xC8A8F0), Color(hex: 0x8A60C0), Color(hex: 0x4A2E78)]
        case .dragon: [Color(hex: 0xB89CFF), Color(hex: 0x6F35FC), Color(hex: 0x3A1CA0)]
        case .dark: [Color(hex: 0x9A8070), Color(hex: 0x4A3A30), .black]
        case .steel: [.white, Color(hex: 0xD8D8E8), Color(hex: 0x9090A8)]
        default: [.white, base, base.opacity(0.8)]
        }
    }

    /// Snaps to the 1 pt grid so particles read as pixels.
    private func pixel(_ point: CGPoint, size: CGFloat) -> CGRect {
        CGRect(x: point.x.rounded() - size / 2, y: point.y.rounded() - size / 2, width: size, height: size)
    }

    /// A stable pseudo-random value per particle.
    private func noise(_ index: Int, _ salt: Int) -> Double {
        var hasher = Hasher()
        hasher.combine(effect.id)
        hasher.combine(index)
        hasher.combine(salt)
        return Double(UInt(bitPattern: hasher.finalize()) % 10_000) / 10_000
    }

    func draw(in canvas: inout GraphicsContext, at t: Double) {
        if !effect.physical, t < effect.travel { drawProjectile(in: &canvas, progress: t / effect.travel) }
        let burst = (t - effect.travel) / (effect.duration - effect.travel)
        guard burst >= 0 else { return }
        drawBurst(in: &canvas, progress: burst)
    }

    private func drawProjectile(in canvas: inout GraphicsContext, progress: Double) {
        let colors = palette
        for trail in 0..<5 {
            let p = max(0, progress - Double(trail) * 0.07)
            let point = CGPoint(x: effect.from.x + (effect.to.x - effect.from.x) * p,
                                y: effect.from.y + (effect.to.y - effect.from.y) * p - sin(p * .pi) * 10)
            let size: CGFloat = trail == 0 ? 5 : max(2, 4 - CGFloat(trail) * 0.6)
            canvas.fill(Path(pixel(point, size: size)), with: .color(colors[min(trail, colors.count - 1)].opacity(1 - Double(trail) * 0.16)))
        }
    }

    private func drawBurst(in canvas: inout GraphicsContext, progress p: Double) {
        let colors = palette
        let center = effect.to
        let count = effect.strong ? 16 : 11
        let fade = 1 - p
        switch style {
        case .flame:
            for i in 0..<count {
                let x = center.x + (noise(i, 1) - 0.5) * 34
                let rise = p * (14 + noise(i, 2) * 22)
                let size: CGFloat = 2 + CGFloat(noise(i, 3) * 3) * (1 - p)
                canvas.fill(Path(pixel(CGPoint(x: x + sin(p * 9 + Double(i)) * 2, y: center.y + 10 - rise), size: size)),
                            with: .color(colors[i % colors.count].opacity(fade)))
            }
        case .splash:
            for i in 0..<count {
                let angle = -.pi * (0.1 + 0.8 * noise(i, 1))
                let speed = 20 + noise(i, 2) * 18
                let point = CGPoint(x: center.x + cos(angle) * speed * p, y: center.y + sin(angle) * speed * p + 40 * p * p)
                canvas.fill(Path(pixel(point, size: i % 3 == 0 ? 3 : 2)), with: .color(colors[i % colors.count].opacity(fade)))
            }
        case .bolt:
            let flicker = Int(p * 12) % 2 == 0
            var path = Path()
            var point = CGPoint(x: center.x + 6, y: center.y - 34)
            path.move(to: point)
            for step in 0..<6 {
                point = CGPoint(x: center.x + (step % 2 == 0 ? -7 : 7) * (1 - p * 0.5), y: point.y + 7)
                path.addLine(to: point)
            }
            canvas.stroke(path, with: .color((flicker ? colors[0] : colors[1]).opacity(fade)), lineWidth: 2)
            for i in 0..<count / 2 {
                let angle = noise(i, 1) * .pi * 2
                let point = CGPoint(x: center.x + cos(angle) * 18 * p, y: center.y + sin(angle) * 14 * p)
                canvas.fill(Path(pixel(point, size: 2)), with: .color(colors[2].opacity(fade)))
            }
        case .leaf:
            for i in 0..<count {
                let angle = noise(i, 1) * .pi * 2
                let radius = (12 + noise(i, 2) * 16) * p
                let point = CGPoint(x: center.x + cos(angle + p * 3) * radius, y: center.y + sin(angle + p * 3) * radius * 0.7 + 8 * p)
                let rect = pixel(point, size: 3)
                canvas.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: 3, height: 2)), with: .color(colors[i % colors.count].opacity(fade)))
            }
        case .shards:
            for i in 0..<count {
                let angle = noise(i, 1) * .pi * 2
                let speed = 16 + noise(i, 2) * 20
                let point = CGPoint(x: center.x + cos(angle) * speed * p, y: center.y + sin(angle) * speed * p)
                var diamond = Path()
                let r: CGFloat = 2.5 * (1 - p * 0.4)
                diamond.move(to: CGPoint(x: point.x, y: point.y - r))
                diamond.addLine(to: CGPoint(x: point.x + r, y: point.y))
                diamond.addLine(to: CGPoint(x: point.x, y: point.y + r))
                diamond.addLine(to: CGPoint(x: point.x - r, y: point.y))
                canvas.fill(diamond, with: .color(colors[i % colors.count].opacity(fade)))
            }
        case .rings:
            for ring in 0..<3 {
                let local = p * 1.3 - Double(ring) * 0.18
                guard local > 0, local < 1 else { continue }
                let radius = 6 + local * 22
                canvas.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.7, width: radius * 2, height: radius * 1.4)),
                              with: .color(colors[ring % colors.count].opacity(1 - local)), lineWidth: 2)
            }
        case .bubbles:
            for i in 0..<count {
                let x = center.x + (noise(i, 1) - 0.5) * 30
                let y = center.y + 12 - p * (10 + noise(i, 2) * 26)
                let r = 1.5 + noise(i, 3) * 2.5
                canvas.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                              with: .color(colors[i % colors.count].opacity(fade)), lineWidth: 1)
            }
        case .gust:
            for i in 0..<6 {
                let y = center.y - 14 + Double(i) * 6
                let length = 10 + noise(i, 1) * 14
                let x = center.x - 26 + p * 30 + noise(i, 2) * 8
                canvas.fill(Path(CGRect(x: x.rounded(), y: y.rounded(), width: length, height: 1.5)),
                            with: .color(Color.white.opacity(fade * 0.9)))
            }
        case .debris:
            for i in 0..<count {
                let x = center.x + (noise(i, 1) - 0.5) * 36
                let fall = -26 + p * (46 + noise(i, 2) * 10)
                let size: CGFloat = i % 3 == 0 ? 4 : 3
                canvas.fill(Path(pixel(CGPoint(x: x, y: center.y + min(fall, 14)), size: size)), with: .color(colors[i % colors.count].opacity(fade)))
            }
        case .impact:
            let radius = 5 + p * 16
            for ray in 0..<8 {
                let angle = Double(ray) / 8 * .pi * 2 + 0.3
                var line = Path()
                line.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.5, y: center.y + sin(angle) * radius * 0.5))
                line.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                canvas.stroke(line, with: .color(colors[ray % 2].opacity(fade)), lineWidth: 2)
            }
        }
        // A white flash on the target for strong hits.
        if effect.strong, p < 0.25 {
            let r = 10 + p * 30
            canvas.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(0.5 * (1 - p * 4))))
        }
    }
}
