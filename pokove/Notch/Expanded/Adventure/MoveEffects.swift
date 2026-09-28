import SwiftUI

/// How a move looks, read from its name: what swings, flies, falls or spreads. Each Pokémon's
/// moves pick their own, in their type's colors.
enum MoveShape: Equatable {
    /// Body blows: a star burst with speed lines.
    case strike
    /// Punches and kicks: a fist slams in and a shock ring spreads.
    case blow
    /// Claws and blades: streaks across the target.
    case slash
    /// Tails and vines: one lash across the target.
    case lash
    /// Fangs that snap shut.
    case bite
    /// Horns, beaks and stingers thrust in.
    case stab
    /// A charged ray from the user to the target.
    case beam
    /// Flames, water or gas pouring across.
    case stream
    /// A ball that flies and bursts.
    case orb
    /// A spray of small shots.
    case volley
    /// Lightning.
    case bolt
    /// The ground shakes and cracks.
    case quake
    /// Rings that ripple out from the user.
    case wave
    /// A whirl of air around the target.
    case wind
    /// Bits of the target float back to the user.
    case drain
    /// Coils that squeeze the target.
    case bind
    /// A gale that sweeps the whole field.
    case storm

    init(_ move: PokeMove) {
        if let shape = Self.named[move.slug] {
            self = shape
            return
        }
        switch move.type {
        case .normal, .steel: self = .strike
        case .fighting: self = .blow
        case .flying: self = .wind
        case .poison, .ghost: self = .orb
        case .ground: self = .quake
        case .rock, .bug, .grass: self = .volley
        case .fire, .water, .dragon: self = .stream
        case .electric: self = .bolt
        case .psychic, .fairy: self = .wave
        case .ice: self = .beam
        case .dark: self = .bite
        }
    }

    private static let named: [String: MoveShape] = {
        let groups: [(MoveShape, [String])] = [
            (.strike, ["tackle", "body-slam", "take-down", "double-edge", "thrash", "outrage", "headbutt", "skull-bash",
                       "quick-attack", "extreme-speed", "rage", "covet", "fake-out", "rapid-spin", "rollout", "flame-wheel",
                       "spark", "astonish", "lick", "knock-off", "feint-attack", "pursuit", "bounce", "sky-attack",
                       "waterfall", "superpower", "revenge", "bone-club", "struggle"]),
            (.blow, ["pound", "double-slap", "comet-punch", "mega-punch", "fire-punch", "ice-punch", "thunder-punch",
                     "dizzy-punch", "mach-punch", "dynamic-punch", "shadow-punch", "sky-uppercut", "brick-break",
                     "karate-chop", "cross-chop", "meteor-mash", "submission", "vital-throw", "seismic-toss",
                     "double-kick", "mega-kick", "jump-kick", "rolling-kick", "low-kick", "high-jump-kick", "stomp"]),
            (.slash, ["scratch", "slash", "fury-swipes", "metal-claw", "fury-cutter", "cut", "aerial-ace", "crabhammer"]),
            (.lash, ["vine-whip", "slam", "iron-tail"]),
            (.bite, ["bite", "crunch", "hyper-fang", "super-fang", "poison-fang", "clamp", "vice-grip"]),
            (.stab, ["peck", "drill-peck", "horn-attack", "megahorn", "fury-attack"]),
            (.beam, ["hyper-beam", "solar-beam", "ice-beam", "aurora-beam", "psybeam", "signal-beam", "zap-cannon", "tri-attack"]),
            (.stream, ["flamethrower", "water-gun", "hydro-pump", "smog", "dragon-breath", "dragon-rage", "mud-slap",
                       "powder-snow", "bubble", "bubble-beam", "acid"]),
            (.orb, ["shadow-ball", "sludge", "sludge-bomb", "egg-bomb", "mud-shot", "fire-blast"]),
            (.volley, ["poison-sting", "pin-missile", "twineedle", "spike-cannon", "swift", "barrage", "icicle-spear",
                       "rock-blast", "magical-leaf", "razor-leaf", "ember", "bonemerang", "rock-throw", "bone-rush",
                       "pay-day", "ancient-power"]),
            (.bolt, ["thunder-shock", "thunderbolt", "thunder"]),
            (.quake, ["earthquake", "magnitude", "dig"]),
            (.wave, ["psychic", "confusion", "hyper-voice", "uproar", "night-shade", "sonic-boom"]),
            (.wind, ["gust", "wing-attack", "twister", "air-cutter", "razor-wind"]),
            (.drain, ["absorb", "mega-drain", "giga-drain", "leech-life"]),
            (.bind, ["wrap", "bind", "constrict", "fire-spin", "sand-tomb", "whirlpool"]),
            (.storm, ["blizzard", "heat-wave", "icy-wind", "silver-wind", "petal-dance"]),
        ]
        var named: [String: MoveShape] = [:]
        for (shape, slugs) in groups { for slug in slugs { named[slug] = shape } }
        return named
    }()

    /// The user runs at the target for these.
    var isContact: Bool {
        switch self {
        case .strike, .blow, .slash, .lash, .bite, .stab: true
        default: false
        }
    }
}

/// One move's visual, from the user to the target, hit by hit.
struct MoveEffect: Identifiable, Equatable {
    let id = UUID()
    let slug: String
    let shape: MoveShape
    let type: PokeType
    let from: CGPoint
    let to: CGPoint
    /// Where the target stands, for what happens on the ground.
    let feet: CGPoint
    let start: Date
    /// 0.9 for weak moves up to 1.35 for the strongest: size and reach.
    let power: Double
    /// A critical or super effective hit: a flash and a shake.
    let strong: Bool
    let hits: Int

    init(move: PokeMove, hits: Int, from: CGPoint, to: CGPoint, feet: CGPoint, strong: Bool, start: Date = .now) {
        slug = move.slug
        shape = MoveShape(move)
        type = move.type
        self.from = from
        self.to = to
        self.feet = feet
        self.start = start
        self.strong = strong
        self.hits = max(1, min(hits, 5))
        let rating: Double = switch move.damage {
        case .power(let power): Double(power)
        case .fixed, .level, .halfHP: 70
        }
        power = min(1.35, max(0.9, 0.7 + rating / 200))
    }

    /// Seconds from the start until the first hit lands.
    var impact: Double {
        switch shape {
        case .strike, .slash: 0.1
        case .blow: 0.16
        case .lash, .stab: 0.13
        case .bite: 0.18
        case .beam: 0.26
        case .stream, .wind, .bind: 0.2
        case .orb, .wave: 0.3
        case .volley: 0.22
        case .bolt: 0.08
        case .quake, .drain: 0.12
        case .storm: 0.25
        }
    }

    /// Seconds between the hits of a move that hits more than once.
    static let spacing = 0.12

    /// When hit `index` lands, from the start.
    func landing(_ index: Int) -> Double { impact + Double(index) * Self.spacing }

    /// How long the last hit's burst lingers.
    private var linger: Double {
        switch shape {
        case .drain: 0.8
        case .quake: 0.62
        case .stream, .storm: 0.58
        case .beam, .wind, .bind, .bolt: 0.52
        default: 0.45
        }
    }

    var duration: Double { landing(hits - 1) + linger + (shape == .volley && hits == 1 ? 0.2 : 0) }

    /// A big move: the scene flashes in its colors.
    var isBig: Bool { power >= 1.15 }

    /// How far the scene shakes when it lands, and for how long.
    var shake: (amount: CGFloat, seconds: Double) {
        if shape == .quake { return (3.2, 0.6) }
        if strong { return (2.4, 0.26) }
        if isBig { return (1.8, 0.22) }
        return shape.isContact ? (1, 0.14) : (0, 0)
    }
}

/// Pixel particles for moves, drawn on one canvas while any effect is alive.
struct MoveEffectsLayer: View {
    let effects: [MoveEffect]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: effects.isEmpty)) { context in
            Canvas { canvas, size in
                for effect in effects {
                    let t = context.date.timeIntervalSince(effect.start)
                    guard t >= 0, t <= effect.duration else { continue }
                    MoveEffectPainter(effect: effect, size: size, flashes: !reduceMotion).draw(in: &canvas, at: t)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MoveEffectPainter {
    let effect: MoveEffect
    let size: CGSize
    let flashes: Bool

    // MARK: Colors

    /// Light, middle and dark, per type, with a few moves in their own colors.
    private var palette: [Color] {
        switch effect.slug {
        case "leech-life": return [Color(hex: 0xFFC0B8), Color(hex: 0xF04848), Color(hex: 0x901820)]
        case "petal-dance": return [Color(hex: 0xFFE0EC), Color(hex: 0xFF8AB8), Color(hex: 0xD04A80)]
        case "egg-bomb": return [.white, Color(hex: 0xFFF2C8), Color(hex: 0xC8A060)]
        case "hyper-beam": return [.white, Color(hex: 0xFFE08A), Color(hex: 0xE8761E)]
        case "solar-beam": return [.white, Color(hex: 0xEFFF9A), Color(hex: 0x4E9E2A)]
        default: break
        }
        let hexes: [UInt32] = switch effect.type {
        case .normal: [0xFFFFFF, 0xECE6C8, 0xA8A77A]
        case .fire: [0xFFE27A, 0xFF8A1E, 0xE0401A]
        case .water: [0xD8F0FF, 0x5AA8FF, 0x2D62D0]
        case .electric: [0xFFFFFF, 0xFFF06A, 0xF2B81A]
        case .grass: [0xD4FF9A, 0x6CC04A, 0x2F7A28]
        case .ice: [0xFFFFFF, 0xBFF2F2, 0x6CC4DC]
        case .fighting: [0xFFE2B0, 0xF07A3A, 0xB02A20]
        case .poison: [0xECC0F4, 0xB050C0, 0x6A2A7A]
        case .ground: [0xF2DC9A, 0xC8A050, 0x7A5A2A]
        case .flying: [0xFFFFFF, 0xDCE4FF, 0xA0A8E8]
        case .psychic: [0xFFD0E4, 0xF95587, 0xB02A68]
        case .bug: [0xEEF59A, 0xB0C428, 0x6A7A10]
        case .rock: [0xE8D8A8, 0xB09A5A, 0x6A5A30]
        case .ghost: [0xD8C0FF, 0x8A60C8, 0x3E2A68]
        case .dragon: [0xC8B0FF, 0x7A48FF, 0x3A1CA0]
        case .dark: [0xB8A8A0, 0x5A4A40, 0x201814]
        case .steel: [0xFFFFFF, 0xD8D8E8, 0x8888A0]
        case .fairy: [0xFFE0F0, 0xF0A0C8, 0xC06090]
        }
        return hexes.map { Color(hex: $0) }
    }

    // MARK: Geometry

    /// From the user toward the target, one point long.
    private var direction: CGVector {
        let dx = effect.to.x - effect.from.x, dy = effect.to.y - effect.from.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// Square to `direction`.
    private var across: CGVector { CGVector(dx: -direction.dy, dy: direction.dx) }

    /// 1 when the user is on the left, -1 on the right.
    private var side: CGFloat { effect.from.x <= effect.to.x ? 1 : -1 }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func offset(_ point: CGPoint, _ vector: CGVector, _ amount: Double) -> CGPoint {
        CGPoint(x: point.x + vector.dx * amount, y: point.y + vector.dy * amount)
    }

    private func polar(_ center: CGPoint, _ angle: Double, _ radius: Double, squash: Double = 1) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * squash)
    }

    /// Where hit `index` lands: the middle, then a little around it.
    private func target(_ index: Int) -> CGPoint {
        guard index > 0 else { return effect.to }
        return CGPoint(x: effect.to.x + (noise(index, 91) - 0.5) * 18, y: effect.to.y + (noise(index, 92) - 0.5) * 14)
    }

    // MARK: Drawing helpers

    /// A stable pseudo-random value per particle.
    private func noise(_ index: Int, _ salt: Int) -> Double {
        var hasher = Hasher()
        hasher.combine(effect.id)
        hasher.combine(index)
        hasher.combine(salt)
        return Double(UInt(bitPattern: hasher.finalize()) % 10_000) / 10_000
    }

    /// Snaps to the 1 pt grid so particles read as pixels.
    private func pixel(_ point: CGPoint, _ size: CGFloat) -> CGRect {
        CGRect(x: (point.x - size / 2).rounded(), y: (point.y - size / 2).rounded(), width: size.rounded(.up), height: size.rounded(.up))
    }

    private func dot(_ canvas: inout GraphicsContext, _ point: CGPoint, _ size: CGFloat, _ color: Color, _ opacity: Double = 1) {
        canvas.fill(Path(pixel(point, max(1, size))), with: .color(color.opacity(max(0, min(1, opacity)))))
    }

    private func line(_ canvas: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ width: CGFloat, _ color: Color, _ opacity: Double = 1) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        canvas.stroke(path, with: .color(color.opacity(max(0, min(1, opacity)))), style: StrokeStyle(lineWidth: max(0.5, width), lineCap: .round))
    }

    private func circle(_ canvas: inout GraphicsContext, _ center: CGPoint, _ radius: CGFloat, _ color: Color, _ opacity: Double = 1) {
        guard radius > 0 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        canvas.fill(Path(ellipseIn: rect), with: .color(color.opacity(max(0, min(1, opacity)))))
    }

    private func ring(_ canvas: inout GraphicsContext, _ center: CGPoint, _ radius: CGFloat, _ width: CGFloat, _ color: Color,
                      _ opacity: Double = 1, squash: CGFloat = 0.72) {
        guard radius > 0 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius * squash, width: radius * 2, height: radius * 2 * squash)
        canvas.stroke(Path(ellipseIn: rect), with: .color(color.opacity(max(0, min(1, opacity)))), lineWidth: max(0.5, width))
    }

    private func star(_ canvas: inout GraphicsContext, _ center: CGPoint, points: Int, outer: CGFloat, inner: CGFloat,
                      rotation: Double, _ color: Color, _ opacity: Double = 1) {
        var path = Path()
        for index in 0..<(points * 2) {
            let angle = rotation + Double(index) * .pi / Double(points) - .pi / 2
            let radius = index % 2 == 0 ? outer : inner
            let point = polar(center, angle, radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        canvas.fill(path, with: .color(color.opacity(max(0, min(1, opacity)))))
    }

    /// Pixels flung out from a point, slowing and falling as they go.
    private func sparks(_ canvas: inout GraphicsContext, at center: CGPoint, progress p: Double, count: Int, reach: Double,
                        size: CGFloat = 3.5, salt: Int = 0, fall: Double = 14) {
        guard p >= 0, p <= 1 else { return }
        let colors = palette
        let ease = 1 - (1 - p) * (1 - p)
        for index in 0..<count {
            let angle = noise(index, salt) * .pi * 2
            let distance = reach * (0.45 + 0.55 * noise(index, salt + 1)) * ease
            var point = polar(center, angle, distance, squash: 0.8)
            point.y += fall * p * p
            let bit = size * (1 - p * 0.5)
            dot(&canvas, point, bit + 1, colors[2], (1 - p) * 0.6)
            dot(&canvas, point, bit, colors[index % 2], 1 - p)
        }
    }

    /// The whole field lit up for a moment.
    private func flash(_ canvas: inout GraphicsContext, _ color: Color, _ opacity: Double) {
        guard flashes, opacity > 0 else { return }
        canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color.opacity(min(1, opacity))))
    }

    // MARK: Moves

    func draw(in canvas: inout GraphicsContext, at t: Double) {
        switch effect.shape {
        case .strike: strike(&canvas, t)
        case .blow: blow(&canvas, t)
        case .slash: slash(&canvas, t)
        case .lash: lash(&canvas, t)
        case .bite: bite(&canvas, t)
        case .stab: stab(&canvas, t)
        case .beam: beam(&canvas, t)
        case .stream: stream(&canvas, t)
        case .orb: orb(&canvas, t)
        case .volley: volley(&canvas, t)
        case .bolt: bolt(&canvas, t)
        case .quake: quake(&canvas, t)
        case .wave: wave(&canvas, t)
        case .wind: wind(&canvas, t)
        case .drain: drain(&canvas, t)
        case .bind: bind(&canvas, t)
        case .storm: storm(&canvas, t)
        }
        // A moment of light as it lands: white for a critical or super effective hit, the
        // move's own color for a big one.
        let local = t - effect.impact
        if local >= 0, local < 0.14 {
            let fade = 1 - local / 0.14
            if effect.strong {
                flash(&canvas, .white, 0.34 * fade)
            } else if effect.isBig {
                flash(&canvas, palette[1], 0.22 * fade)
            }
        }
    }

    private func strike(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        for hit in 0..<effect.hits {
            let p = (t - effect.landing(hit)) / 0.42
            guard p >= 0, p <= 1 else { continue }
            let center = target(hit)
            if p < 0.4 {
                let q = p / 0.4
                let radius = (13 + 11 * q) * power
                let spin = noise(hit, 5) * .pi
                star(&canvas, center, points: 8, outer: radius + 2, inner: radius * 0.42 + 1, rotation: spin, colors[2], (1 - q) * 0.8)
                star(&canvas, center, points: 8, outer: radius, inner: radius * 0.42, rotation: spin, colors[1], 1 - q)
                star(&canvas, center, points: 8, outer: radius * 0.62, inner: radius * 0.28, rotation: spin, colors[0], 1 - q * 0.8)
            }
            for ray in 0..<10 {
                let angle = Double(ray) / 10 * .pi * 2 + noise(ray, 7) * 0.4
                let inner = (11 + p * 28) * power
                let outer = inner + (14 * (1 - p) + 3) * power
                line(&canvas, polar(center, angle, inner, squash: 0.8), polar(center, angle, outer, squash: 0.8), 2.5,
                     colors[ray % 2 == 0 ? 0 : 2], 1 - p)
            }
            sparks(&canvas, at: center, progress: p, count: 10, reach: 32 * power, salt: hit * 10)
        }
    }

    /// A fist, knuckles up: `o` in the move's light color, `#` in its dark one.
    private static let fist = [
        ".##.##.##.",
        "#oo#oo#oo#",
        "#oo#oo#oo#",
        "#oooooooo#",
        "#####oooo#",
        "#oooo#ooo#",
        ".#oooooo#.",
        "..######..",
    ]

    private func blow(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        for hit in 0..<effect.hits {
            let local = t - effect.landing(hit)
            let center = target(hit)
            // The fist comes at the screen and shrinks onto the target.
            if local >= -0.16, local < 0.22 {
                let approach = min(1, (local + 0.16) / 0.16)
                let scale = (2.6 - 1.6 * approach) * power
                let opacity = local < 0 ? approach : 1 - local / 0.22
                let cell = 2.4 * scale
                let rows = Self.fist
                let width = CGFloat(rows[0].count) * cell, height = CGFloat(rows.count) * cell
                for (row, line) in rows.enumerated() {
                    for (column, mark) in line.enumerated() where mark != "." {
                        let x = center.x - width / 2 + CGFloat(column) * cell
                        let y = center.y - height / 2 + CGFloat(row) * cell
                        let color = mark == "o" ? colors[0] : colors[2]
                        canvas.fill(Path(CGRect(x: x, y: y, width: cell + 0.3, height: cell + 0.3)), with: .color(color.opacity(opacity)))
                    }
                }
            }
            let p = local / 0.42
            guard p >= 0, p <= 1 else { continue }
            ring(&canvas, center, (10 + 30 * p) * power, 5 * (1 - p) + 1, colors[2], (1 - p) * 0.7)
            ring(&canvas, center, (10 + 30 * p) * power, 3 * (1 - p) + 0.8, colors[1], 1 - p)
            ring(&canvas, center, (5 + 18 * p) * power, 2 * (1 - p) + 0.5, colors[0], (1 - p) * 0.8)
            sparks(&canvas, at: center, progress: p, count: 12, reach: 34 * power, salt: hit * 10)
        }
    }

    private func slash(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let claws = ["scratch", "fury-swipes", "metal-claw", "crabhammer"].contains(effect.slug)
        for hit in 0..<effect.hits {
            let local = t - effect.landing(hit) + 0.1
            guard local >= 0 else { continue }
            let drawn = min(1, local / 0.12)
            let fade = max(0, (local - 0.14) / 0.32)
            guard fade < 1 else { continue }
            let center = target(hit)
            let flip: CGFloat = (hit % 2 == 0 ? 1 : -1) * side
            let reach = 21 * power
            let marks = claws ? [-8.0, 0, 8] : [0.0]
            for mark in marks {
                let start = CGPoint(x: center.x - reach * flip + mark, y: center.y - reach + mark * 0.3)
                let end = CGPoint(x: center.x + reach * flip + mark, y: center.y + reach + mark * 0.3)
                let tip = lerp(start, end, drawn)
                let width: CGFloat = claws ? 3 : 4.5
                line(&canvas, start, tip, width + 3.5, colors[2], (1 - fade) * 0.7)
                line(&canvas, start, tip, width + 1.5, colors[1], 1 - fade)
                line(&canvas, start, tip, width * 0.5, .white, 1 - fade)
            }
            if local >= 0.1 {
                sparks(&canvas, at: center, progress: (local - 0.1) / 0.35, count: 8, reach: 26 * power, salt: hit * 10)
            }
        }
    }

    private func lash(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let center = effect.to
        let local = t - effect.impact + 0.13
        guard local >= 0 else { return }
        let drawn = min(1, local / 0.15)
        let fade = max(0, (local - 0.18) / 0.3)
        guard fade < 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: center.x - 34 * side, y: center.y - 24))
        path.addQuadCurve(to: CGPoint(x: center.x + 26 * side, y: center.y + 18),
                          control: CGPoint(x: center.x + 18 * side, y: center.y - 30))
        let trimmed = path.trimmedPath(from: max(0, drawn - 0.55), to: drawn)
        let width = (effect.slug == "vine-whip" ? 3.5 : 5) * power
        canvas.stroke(trimmed, with: .color(colors[2].opacity(1 - fade)), style: StrokeStyle(lineWidth: width + 2, lineCap: .round))
        canvas.stroke(trimmed, with: .color(colors[1].opacity(1 - fade)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        canvas.stroke(trimmed, with: .color(colors[0].opacity(1 - fade)), style: StrokeStyle(lineWidth: max(1, width * 0.35), lineCap: .round))
        if local >= 0.13 {
            let p = (local - 0.13) / 0.35
            star(&canvas, center, points: 4, outer: 12 * power * (1 - p * 0.5), inner: 3, rotation: 0.4, colors[0], 1 - p * 2)
            sparks(&canvas, at: center, progress: p, count: 8, reach: 24 * power, size: 3)
        }
    }

    private func bite(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let center = effect.to
        let close = min(1, t / effect.impact)
        let eased = close * close
        let local = t - effect.impact
        let fade = max(0, (local - 0.1) / 0.24)
        guard fade < 1 else { return sparks(&canvas, at: center, progress: local / 0.45, count: 8, reach: 24 * power) }
        let gap = 26 * (1 - eased) + 3
        let span = 40 * power
        let teeth = 5
        for jaw in [-1.0, 1.0] {
            let edge = center.y + gap * jaw
            let gum = CGRect(x: center.x - span / 2 - 2, y: edge + (jaw < 0 ? -6 : 2), width: span + 4, height: 4)
            canvas.fill(Path(gum), with: .color(colors[2].opacity(1 - fade)))
            let width = span / CGFloat(teeth)
            for tooth in 0..<teeth {
                let left = center.x - span / 2 + CGFloat(tooth) * width
                var path = Path()
                path.move(to: CGPoint(x: left, y: edge + (jaw < 0 ? -2 : 2)))
                path.addLine(to: CGPoint(x: left + width, y: edge + (jaw < 0 ? -2 : 2)))
                path.addLine(to: CGPoint(x: left + width / 2, y: edge - jaw * 9 * power))
                path.closeSubpath()
                canvas.fill(path, with: .color(Color.white.opacity(1 - fade)))
                canvas.stroke(path, with: .color(colors[2].opacity((1 - fade) * 0.8)), lineWidth: 0.8)
            }
        }
        if local >= 0 { sparks(&canvas, at: center, progress: local / 0.45, count: 8, reach: 24 * power) }
    }

    private func stab(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        for hit in 0..<effect.hits {
            let local = t - effect.landing(hit)
            let center = target(hit)
            if local >= -0.12, local < 0.12 {
                let q = min(1, (local + 0.12) / 0.12)
                let tip = offset(center, direction, -30 * (1 - q * q) + 3)
                let base = offset(tip, direction, -24 * power)
                let half = 5 * power
                var wedge = Path()
                wedge.move(to: tip)
                wedge.addLine(to: offset(base, across, half))
                wedge.addLine(to: offset(base, across, -half))
                wedge.closeSubpath()
                let opacity = local < 0 ? 1 : 1 - local / 0.12
                canvas.fill(wedge, with: .color(colors[0].opacity(opacity)))
                canvas.stroke(wedge, with: .color(colors[2].opacity(opacity)), lineWidth: 1.5)
                line(&canvas, offset(base, direction, -10), base, 1.5, colors[1], opacity * 0.6)
            }
            let p = local / 0.38
            guard p >= 0, p <= 1 else { continue }
            for ray in 0..<6 {
                let angle = Double(ray) / 6 * .pi * 2 + 0.5
                line(&canvas, polar(center, angle, (5 + 16 * p) * power), polar(center, angle, (12 + 24 * p) * power), 2.5,
                     colors[ray % 2 == 0 ? 0 : 2], 1 - p)
            }
            ring(&canvas, center, (6 + 18 * p) * power, 2, colors[1], 1 - p)
        }
    }

    private func beam(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let charge = 0.12
        let ends = effect.impact + 0.34
        // Light gathers at the user.
        if t < charge + 0.06 {
            let q = min(1, t / charge)
            for index in 0..<12 {
                let angle = noise(index, 1) * .pi * 2
                dot(&canvas, polar(effect.from, angle, 24 * (1 - q) + 2), 2, colors[index % 3], q)
            }
            circle(&canvas, effect.from, (2 + 5 * q) * power, colors[0], 0.9)
        }
        // The ray: tri-attack's three colors, aurora beam's rainbow, one color for the rest.
        if t >= charge, t < ends {
            let grow = min(1, (t - charge) / (effect.impact - charge))
            let shrink = t > ends - 0.14 ? max(0, (ends - t) / 0.14) : 1
            let pulse = 1 + 0.22 * sin(t * 70)
            let width = 7.5 * power * pulse * shrink
            let rays: [(CGFloat, [Color])]
            switch effect.slug {
            case "tri-attack":
                rays = [(-5, [Color(hex: 0xFFB060), Color(hex: 0xF05030)]), (0, [Color(hex: 0xD8FAFF), Color(hex: 0x60B8F0)]),
                        (5, [Color(hex: 0xFFFFC0), Color(hex: 0xF7D02C)])]
            case "aurora-beam":
                let hue = (t * 2.5).truncatingRemainder(dividingBy: 1)
                rays = [(0, [Color(hue: hue, saturation: 0.25, brightness: 1), Color(hue: hue, saturation: 0.6, brightness: 1)])]
            default:
                rays = [(0, [colors[0], colors[1]])]
            }
            for (shift, tones) in rays {
                let start = offset(effect.from, across, shift)
                let end = offset(lerp(effect.from, effect.to, grow), across, shift * 0.4)
                let scale: CGFloat = rays.count > 1 ? 0.5 : 1
                line(&canvas, start, end, width * 2.4 * scale, tones[1], 0.3)
                line(&canvas, start, end, width * scale + 3, colors[2], 0.75)
                line(&canvas, start, end, width * scale, tones[1], 1)
                line(&canvas, start, end, width * 0.45 * scale, tones[0], 1)
                circle(&canvas, end, width * scale + 1.5, colors[2], 0.75)
                circle(&canvas, end, width * scale, tones[0], 1)
            }
            circle(&canvas, effect.from, width + 1, colors[2], 0.6)
            circle(&canvas, effect.from, width * 0.9, colors[0], 1)
            // Rings ride along a psybeam.
            if effect.slug == "psybeam" {
                for index in 0..<4 {
                    let along = (t * 3 + Double(index) * 0.25).truncatingRemainder(dividingBy: 1) * grow
                    ring(&canvas, lerp(effect.from, effect.to, along), 5 * power, 1.2, colors[0], 0.8, squash: 1)
                }
            }
        }
        let p = (t - effect.impact) / 0.5
        guard p >= 0, p <= 1 else { return }
        ring(&canvas, effect.to, (10 + 30 * p) * power, 4 * (1 - p) + 0.8, colors[2], (1 - p) * 0.6)
        ring(&canvas, effect.to, (10 + 30 * p) * power, 2.5 * (1 - p) + 0.5, colors[1], 1 - p)
        sparks(&canvas, at: effect.to, progress: p, count: 16, reach: 38 * power, size: 4)
    }

    private func stream(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let flow = 0.4
        let travel = effect.impact
        let count = Int(32 * power)
        let bubbles = effect.slug.contains("bubble")
        for index in 0..<count {
            let emitted = Double(index) / Double(count) * flow
            let local = t - emitted
            guard local >= 0 else { continue }
            let q = local / travel
            let color = colors[index % 3]
            if q <= 1 {
                let sway = sin(q * .pi * 2 + noise(index, 1) * 6) * (1.5 + 5 * q) * (noise(index, 2) - 0.5) * 2
                let point = offset(lerp(effect.from, effect.to, q), across, sway)
                switch effect.type {
                case .fire, .dragon:
                    let size = (3 + 5 * q) * power
                    dot(&canvas, point, size + 1.5, colors[2], 0.7)
                    dot(&canvas, point, size, colors[index % 2], 1)
                case .water where bubbles:
                    ring(&canvas, point, 2.5 + 2.5 * noise(index, 3), 1.5, colors[2], 0.8, squash: 1)
                    dot(&canvas, CGPoint(x: point.x - 1, y: point.y - 1), 1.5, .white)
                case .poison, .ground:
                    circle(&canvas, point, (2.5 + 4.5 * q) * power + 1, colors[2], 0.6)
                    circle(&canvas, point, (2.5 + 4.5 * q) * power, color, 0.9)
                case .ice:
                    flake(&canvas, point, colors[2], 1, size: 2.5)
                    flake(&canvas, point, .white, 1, size: 1.5)
                default:
                    dot(&canvas, point, 4 * power + 1.5, colors[2], 0.8)
                    dot(&canvas, point, 4 * power, colors[index % 2], 1)
                }
            } else {
                // What's left of each bit where it hits.
                let s = (local - travel) / 0.3
                guard s < 1 else { continue }
                let angle = noise(index, 4) * .pi * 2
                let spread = 6 + 16 * noise(index, 5)
                var point = polar(effect.to, angle, spread * s, squash: 0.8)
                switch effect.type {
                case .fire, .dragon:
                    point.y -= 18 * s
                    dot(&canvas, point, 4.5 * (1 - s) * power + 1, color, 1 - s)
                case .water where bubbles:
                    ring(&canvas, point, 2.5 + 4 * s, 1.5, colors[0], 1 - s, squash: 1)
                case .water:
                    point.y += 26 * s * s - 10 * s
                    dot(&canvas, point, 3.5, color, 1 - s)
                case .poison, .ground:
                    circle(&canvas, point, 4 + 6 * s, color, (1 - s) * 0.75)
                default:
                    dot(&canvas, point, 3, color, 1 - s)
                }
            }
        }
    }

    /// A plus-shaped snowflake.
    private func flake(_ canvas: inout GraphicsContext, _ point: CGPoint, _ color: Color, _ opacity: Double, size: CGFloat = 2) {
        for (dx, dy) in [(0.0, 0.0), (-1.0, 0), (1, 0), (0, -1), (0, 1)] {
            dot(&canvas, CGPoint(x: point.x + dx * size, y: point.y + dy * size), size, color, opacity)
        }
    }

    private func orb(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let travel = effect.impact
        if t < travel {
            let q = t / travel
            let eased = q * q * (3 - 2 * q)
            func place(_ at: Double) -> CGPoint {
                var point = lerp(effect.from, effect.to, at)
                point.y -= sin(at * .pi) * 14
                return point
            }
            let radius = (5.5 + 3 * power) * (0.7 + 0.3 * eased)
            for trail in 1...4 {
                let back = max(0, eased - Double(trail) * 0.06)
                circle(&canvas, place(back), radius * (1 - CGFloat(trail) * 0.18), colors[1], 0.5 - Double(trail) * 0.1)
            }
            let center = place(eased)
            if effect.slug == "egg-bomb" {
                let rect = CGRect(x: center.x - radius * 0.8, y: center.y - radius, width: radius * 1.6, height: radius * 2)
                canvas.fill(Path(ellipseIn: rect), with: .color(.white))
                canvas.stroke(Path(ellipseIn: rect), with: .color(colors[2]), lineWidth: 1)
                dot(&canvas, CGPoint(x: center.x + 1, y: center.y - 1), 2, colors[2])
            } else {
                circle(&canvas, center, radius + 1.5, colors[2], 0.9)
                circle(&canvas, center, radius, colors[1])
                circle(&canvas, CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3), radius * 0.45, colors[0])
                // A dark swirl on a shadow ball.
                if effect.type == .ghost {
                    let spin = t * 24
                    line(&canvas, polar(center, spin, radius * 0.7), polar(center, spin + .pi, radius * 0.7), 1.2, colors[2], 0.9)
                }
            }
        }
        let p = (t - travel) / 0.45
        guard p >= 0, p <= 1 else { return }
        if effect.slug == "fire-blast" {
            // The kanji 大, the way the games draw it.
            let reach = (10 + 22 * (1 - (1 - p) * (1 - p))) * power
            let arms: [Double] = [-.pi / 2, 0, .pi, .pi * 0.3, .pi * 0.7]
            for (index, angle) in arms.enumerated() {
                let end = polar(effect.to, angle, reach)
                line(&canvas, effect.to, end, 6 * (1 - p) + 1.5, colors[2], 1 - p)
                line(&canvas, effect.to, end, 3.5 * (1 - p) + 1, colors[index % 2 == 0 ? 1 : 0], 1 - p)
            }
        } else {
            if p < 0.35 {
                circle(&canvas, effect.to, (9 + 26 * p) * power + 1.5, colors[2], 0.6 * (1 - p / 0.35))
                circle(&canvas, effect.to, (9 + 26 * p) * power, colors[0], 0.9 * (1 - p / 0.35))
            }
            ring(&canvas, effect.to, (10 + 30 * p) * power, 3.5 * (1 - p) + 0.8, colors[1], 1 - p)
        }
        sparks(&canvas, at: effect.to, progress: p, count: 16, reach: 38 * power, size: 4, fall: 20)
    }

    /// How many shots a single-hit volley throws.
    private var shots: Int {
        if effect.hits > 1 { return effect.hits }
        return switch effect.slug {
        case "swift": 5
        case "razor-leaf", "magical-leaf": 4
        case "rock-throw", "poison-sting": 2
        default: 3
        }
    }

    private func volley(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let travel = effect.impact
        let count = shots
        for shot in 0..<count {
            let arrives = effect.hits > 1 ? effect.landing(shot) : effect.impact + Double(shot) * 0.06
            let local = t - (arrives - travel)
            guard local >= 0 else { continue }
            let q = local / travel
            let spread = (Double(shot) - Double(count - 1) / 2) * 7
            let landing = CGPoint(x: effect.to.x + (noise(shot, 3) - 0.5) * 14, y: effect.to.y + (noise(shot, 4) - 0.5) * 12)
            if q <= 1 {
                let heavy = effect.type == .rock || effect.slug == "ancient-power"
                var point = lerp(offset(effect.from, across, spread), landing, q)
                point.y -= sin(q * .pi) * (heavy ? 16 : 4)
                projectile(&canvas, point, spin: t * 18 + Double(shot), colors: colors, power: power)
            } else {
                let p = (q - 1) * travel / 0.3
                sparks(&canvas, at: landing, progress: p, count: 7, reach: 18 * power, size: 3, salt: shot * 10)
            }
        }
    }

    /// One shot of a volley, drawn as what the move throws.
    private func projectile(_ canvas: inout GraphicsContext, _ point: CGPoint, spin: Double, colors: [Color], power: Double) {
        switch effect.slug {
        case "swift":
            star(&canvas, point, points: 5, outer: 7.5 * power, inner: 3.4 * power, rotation: spin, Color(hex: 0xC89A20))
            star(&canvas, point, points: 5, outer: 6 * power, inner: 2.7 * power, rotation: spin, Color(hex: 0xFFE14D))
            star(&canvas, point, points: 5, outer: 3 * power, inner: 1.3 * power, rotation: spin, .white)
        case "pin-missile", "poison-sting", "twineedle", "spike-cannon", "icicle-spear":
            let tail = offset(point, direction, -11 * power)
            line(&canvas, tail, point, 3, colors[2])
            line(&canvas, offset(point, direction, -4), point, 2.5, colors[0])
        case "razor-leaf", "magical-leaf":
            let tip = polar(point, spin, 5.5 * power), back = polar(point, spin + .pi, 5.5 * power)
            let sideA = polar(point, spin + .pi / 2, 2.6 * power), sideB = polar(point, spin - .pi / 2, 2.6 * power)
            var leaf = Path()
            leaf.move(to: tip)
            leaf.addLine(to: sideA)
            leaf.addLine(to: back)
            leaf.addLine(to: sideB)
            leaf.closeSubpath()
            canvas.fill(leaf, with: .color(effect.slug == "magical-leaf" ? Color(hue: spin.truncatingRemainder(dividingBy: 1), saturation: 0.45, brightness: 1) : colors[1]))
            canvas.stroke(leaf, with: .color(colors[2]), lineWidth: 1)
            line(&canvas, tip, back, 0.8, colors[2])
        case "bonemerang", "bone-rush":
            let a = polar(point, spin, 6.5 * power), b = polar(point, spin + .pi, 6.5 * power)
            line(&canvas, a, b, 4, Color(hex: 0x8A7A5A))
            line(&canvas, a, b, 2.5, Color(hex: 0xF4ECD8))
            circle(&canvas, a, 2.8, Color(hex: 0xF4ECD8))
            circle(&canvas, b, 2.8, Color(hex: 0xF4ECD8))
        case "pay-day":
            circle(&canvas, point, 4.5, Color(hex: 0xA87A10))
            circle(&canvas, point, 3.2, Color(hex: 0xFFE14D))
        case "ember":
            dot(&canvas, point, 6 * power + 1.5, colors[2])
            dot(&canvas, point, 6 * power, colors[1])
            dot(&canvas, CGPoint(x: point.x, y: point.y - 1), 3, colors[0])
        default:
            let size = (effect.type == .rock ? 7 : 5) * power
            dot(&canvas, point, size + 1.5, colors[2])
            dot(&canvas, point, size, colors[1])
            dot(&canvas, CGPoint(x: point.x - 1, y: point.y - 1), size * 0.4, colors[0])
        }
    }

    private func bolt(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let fromSky = effect.slug == "thunder"
        let ends = effect.impact + 0.34
        let frame = Int(t * 30)
        if t < ends, frame % 4 != 3 {
            let start = fromSky ? CGPoint(x: effect.to.x + (noise(frame, 8) - 0.5) * 16, y: -4) : effect.from
            let end = effect.to
            let steps = 8
            let grow = min(1, t / effect.impact)
            var points: [CGPoint] = []
            for step in 0...steps {
                let q = Double(step) / Double(steps) * grow
                let base = lerp(start, end, q)
                let jitter = step == 0 || (step == steps && grow >= 1) ? 0 : (noise(frame * 16 + step, 9) - 0.5) * 16
                points.append(fromSky ? CGPoint(x: base.x + jitter, y: base.y) : offset(base, across, jitter))
            }
            var path = Path()
            path.addLines(points)
            let width = (fromSky ? 6.5 : 4.5) * power
            canvas.stroke(path, with: .color(colors[2].opacity(0.45)), style: StrokeStyle(lineWidth: width * 2, lineCap: .round, lineJoin: .round))
            canvas.stroke(path, with: .color(colors[1]), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            canvas.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: max(1, width * 0.35), lineCap: .round, lineJoin: .round))
            // Two forks off the main bolt.
            for fork in 0..<2 where points.count > 4 {
                let root = points[2 + fork * 3 < points.count ? 2 + fork * 3 : points.count - 1]
                let angle = (fork == 0 ? -0.6 : 2.4) + noise(frame, 20 + fork)
                line(&canvas, root, polar(root, angle, 10 * power), 1.5, colors[1], 0.9)
            }
        }
        let p = (t - effect.impact) / 0.5
        guard p >= 0, p <= 1 else { return }
        if p < 0.15, fromSky || effect.isBig { flash(&canvas, .white, 0.3 * (1 - p / 0.15)) }
        // Crackle around the target.
        for arc in 0..<6 where (frame + arc) % 3 != 0 {
            let angle = Double(arc) / 6 * .pi * 2 + noise(frame, arc)
            let a = polar(effect.to, angle, (6 + 12 * p) * power)
            let mid = polar(effect.to, angle + 0.25, (10 + 16 * p) * power)
            let b = polar(effect.to, angle, (14 + 20 * p) * power)
            var zig = Path()
            zig.addLines([a, mid, b])
            canvas.stroke(zig, with: .color(colors[arc % 2].opacity(1 - p)), lineWidth: 1.5)
        }
        ring(&canvas, effect.to, (8 + 22 * p) * power, 2, colors[1], 1 - p)
    }

    private func quake(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let ground = effect.feet
        let life = effect.duration
        let fade = t > life - 0.25 ? max(0, (life - t) / 0.25) : 1
        // Cracks run out along the ground.
        let grow = min(1, t / 0.3)
        for crack in 0..<4 {
            let direction: CGFloat = crack % 2 == 0 ? 1 : -1
            var point = CGPoint(x: ground.x, y: ground.y - 1)
            var path = Path()
            path.move(to: point)
            let steps = 5
            for step in 1...steps where Double(step) / Double(steps) <= grow + 0.001 {
                point = CGPoint(x: point.x + direction * (7 + 5 * noise(crack * 10 + step, 1)) * power,
                                y: ground.y - 1 + (noise(crack * 10 + step, 2) - 0.5) * 5 + CGFloat(crack / 2) * 3)
                path.addLine(to: point)
            }
            canvas.stroke(path, with: .color(Color.black.opacity(0.35 * fade)), style: StrokeStyle(lineWidth: 4, lineJoin: .miter))
            canvas.stroke(path, with: .color(colors[2].opacity(fade)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .miter))
        }
        // Rocks thrown up, and dust along the ground.
        let local = t - effect.impact
        guard local >= 0 else { return }
        let tight = effect.slug == "dig"
        for rock in 0..<16 {
            let launch = noise(rock, 3) * 0.12
            let age = local - launch
            guard age >= 0 else { continue }
            let x = ground.x + (noise(rock, 4) - 0.5) * (tight ? 24 : 64) + (noise(rock, 5) - 0.5) * 30 * age
            let rise = (tight ? 330 : 280) * (0.6 + 0.4 * noise(rock, 6))
            let y = ground.y - rise * age + 500 * age * age
            guard y <= ground.y + 2 else { continue }
            let chunk = (rock % 3 == 0 ? 6 : 4) * power
            dot(&canvas, CGPoint(x: x, y: y), chunk + 1.5, colors[2], fade)
            dot(&canvas, CGPoint(x: x, y: y), chunk, colors[rock % 2], fade)
        }
        // A shock runs out along the ground.
        let wave = min(1, local / 0.45)
        ring(&canvas, CGPoint(x: ground.x, y: ground.y - 1), 12 + 90 * wave, 3 * (1 - wave) + 1, colors[2], (1 - wave) * 0.8, squash: 0.16)
        ring(&canvas, CGPoint(x: ground.x, y: ground.y - 1), 8 + 60 * wave, 2 * (1 - wave) + 1, colors[0], (1 - wave) * 0.8, squash: 0.16)
        for puff in 0..<6 {
            let x = ground.x + (Double(puff) - 2.5) * 12 * power
            let radius = (4 + 10 * min(1, local / 0.4)) * (0.7 + 0.3 * noise(puff, 7))
            circle(&canvas, CGPoint(x: x, y: ground.y - radius * 0.5), radius, colors[0], 0.45 * fade)
        }
    }

    private func wave(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let travel = effect.impact
        let heading = atan2(direction.dy, direction.dx)
        // The screen dims for a night shade, and glows for a psychic move.
        let whole = min(1, t / 0.12) * max(0, min(1, (effect.duration - t) / 0.2))
        if effect.slug == "night-shade" {
            flash(&canvas, .black, 0.38 * whole)
        } else if effect.type == .psychic {
            flash(&canvas, colors[1], (0.1 + 0.06 * sin(t * 30)) * whole)
        }
        // Arcs travel from the user.
        for arc in 0..<4 {
            let local = t - Double(arc) * 0.06
            guard local >= 0 else { continue }
            let q = local / travel
            guard q <= 1.15 else { continue }
            let center = lerp(effect.from, effect.to, min(1, q))
            let radius = (8 + 12 * q) * power
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .radians(heading - 0.9), endAngle: .radians(heading + 0.9), clockwise: false)
            let opacity = q > 1 ? max(0, 1 - (q - 1) / 0.15) : 1
            canvas.stroke(path, with: .color(colors[2].opacity(opacity * 0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            canvas.stroke(path, with: .color(colors[arc % 2].opacity(opacity)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        // Rings close around the target, then ripple out.
        for pulse in 0..<3 {
            let p = (t - effect.impact - Double(pulse) * 0.08) / 0.36
            guard p >= 0, p <= 1 else { continue }
            ring(&canvas, effect.to, (8 + 28 * p) * power, 3 * (1 - p) + 0.8, colors[pulse % 2], 1 - p)
        }
    }

    private func wind(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let heading = atan2(direction.dy, direction.dx)
        // Crescents of air fly at the target.
        for blade in 0..<3 {
            let q = (t - Double(blade) * 0.04) / effect.impact
            guard q >= 0, q <= 1 else { continue }
            let center = offset(lerp(effect.from, effect.to, q), across, (Double(blade) - 1) * 9)
            var path = Path()
            path.addArc(center: center, radius: 9 * power, startAngle: .radians(heading - 1.1), endAngle: .radians(heading + 1.1), clockwise: false)
            canvas.stroke(path, with: .color(colors[2].opacity(0.7)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            canvas.stroke(path, with: .color(colors[0]), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        let p = (t - effect.impact) / 0.5
        guard p >= 0, p <= 1 else { return }
        if effect.slug == "twister" {
            // A column of rings winding up from the ground.
            for level in 0..<7 {
                let y = effect.feet.y - CGFloat(level) * 7 * power
                let width = (8 + CGFloat(level) * 4) * power * (0.8 + 0.2 * CGFloat(sin(p * 20 + Double(level))))
                ring(&canvas, CGPoint(x: effect.to.x + sin(p * 12 + Double(level)) * 3, y: y), width, 2, colors[level % 2], (1 - p) * 0.9, squash: 0.3)
            }
            return
        }
        // Three arms whirling around the target.
        for arm in 0..<3 {
            for step in 0..<9 {
                let angle = Double(arm) * .pi * 2 / 3 + Double(step) * 0.38 + p * 10
                let radius = (5 + Double(step) * 3.2) * (1 + p * 0.4) * power
                let opacity = (1 - p) * (1 - Double(step) / 11)
                let point = polar(effect.to, angle, radius, squash: 0.6)
                dot(&canvas, point, 4.5, colors[2], opacity * 0.6)
                dot(&canvas, point, 3, step % 3 == 0 ? colors[1] : colors[0], opacity)
            }
        }
        sparks(&canvas, at: effect.to, progress: p, count: 6, reach: 26 * power, size: 2.5, fall: 0)
    }

    private func drain(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let hit = (t - effect.impact) / 0.3
        if hit >= 0, hit <= 1 {
            ring(&canvas, effect.to, (6 + 14 * hit) * effect.power, 2, colors[1], 1 - hit)
        }
        // Glowing bits float from the target back to the user.
        for bit in 0..<9 {
            let q = (t - effect.impact - Double(bit) * 0.04) / 0.4
            guard q >= 0, q <= 1 else { continue }
            let eased = q * q * (3 - 2 * q)
            let middle = offset(lerp(effect.to, effect.from, 0.5), across, (noise(bit, 1) - 0.5) * 60)
            let control = CGPoint(x: middle.x, y: middle.y - 18)
            let a = lerp(effect.to, control, eased), b = lerp(control, effect.from, eased)
            let point = lerp(a, b, eased)
            circle(&canvas, point, 6, colors[1], 0.4)
            circle(&canvas, point, 3.5, colors[2], 0.8)
            dot(&canvas, point, 3, colors[0])
        }
        // A glint on the user as it heals.
        let heal = (t - effect.impact - 0.4) / 0.35
        guard heal >= 0, heal <= 1 else { return }
        for glint in 0..<5 {
            let point = CGPoint(x: effect.from.x + (noise(glint, 5) - 0.5) * 30, y: effect.from.y + 8 - heal * 22 - noise(glint, 6) * 8)
            star(&canvas, point, points: 4, outer: 5, inner: 1.4, rotation: 0, colors[1], 1 - heal)
        }
    }

    private func bind(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let power = effect.power
        let appear = min(1, t / effect.impact)
        let life = effect.duration
        let fade = t > life - 0.2 ? max(0, (life - t) / 0.2) : 1
        let squeeze = t > effect.impact ? 0.5 + 0.5 * sin((t - effect.impact) * 22) : 0
        let fire = effect.type == .fire
        let sand = effect.type == .ground
        // Beads around three coils: dim behind the target, bright in front.
        for coil in 0..<3 {
            let y = effect.to.y + (CGFloat(coil) - 1) * 10
            let width = (42 - 12 * appear - 6 * squeeze) * power * (1 + (1 - appear) * 0.6)
            for bead in 0..<22 {
                let angle = Double(bead) / 22 * .pi * 2 + t * (coil % 2 == 0 ? 9 : -9)
                let front = sin(angle) > 0
                let point = CGPoint(x: effect.to.x + cos(angle) * width / 2, y: y + sin(angle) * 4)
                let color = fire ? colors[bead % 3] : (sand ? colors[bead % 2] : (front ? colors[1] : colors[2]))
                var spot = point
                if fire { spot.y -= CGFloat(noise(bead, coil)) * 4 }
                if front { dot(&canvas, spot, 5, colors[2], appear * fade * 0.6) }
                dot(&canvas, spot, front ? 3.5 : 2.5, color, appear * fade * (front ? 1 : 0.5))
            }
        }
    }

    private func storm(_ canvas: inout GraphicsContext, _ t: Double) {
        let colors = palette
        let life = effect.duration
        let whole = min(1, t / 0.1) * max(0, min(1, (life - t) / 0.2))
        switch effect.type {
        case .ice: flash(&canvas, .white, 0.18 * whole)
        case .fire: flash(&canvas, Color(hex: 0xFF8A1E), 0.16 * whole)
        default: break
        }
        let start: CGFloat = side > 0 ? -12 : size.width + 12
        for index in 0..<56 {
            let local = t - noise(index, 1) * 0.35
            guard local >= 0 else { continue }
            let speed = 300 + noise(index, 2) * 180
            let x = start + side * speed * local
            let y = noise(index, 3) * size.height * 0.82 + sin(local * 10 + Double(index)) * 4
            guard x > -20, x < size.width + 20 else { continue }
            let point = CGPoint(x: x, y: y)
            switch effect.slug {
            case "blizzard", "icy-wind":
                flake(&canvas, point, colors[2], 0.9, size: 3)
                flake(&canvas, point, .white, 1, size: 2)
            case "heat-wave": line(&canvas, point, CGPoint(x: x - side * 12, y: y + sin(local * 20) * 3), 3, colors[index % 3], 0.85)
            case "petal-dance":
                dot(&canvas, point, 5.5, colors[2], 0.8)
                dot(&canvas, point, 4, colors[index % 2])
            case "silver-wind": dot(&canvas, point, index % 3 == 0 ? 3.5 : 2.5, index % 2 == 0 ? .white : Color(hex: 0xB8B8D0))
            default: line(&canvas, point, CGPoint(x: x - side * 14, y: y), 2.5, .white, 0.9)
            }
        }
        let p = (t - effect.impact) / 0.45
        sparks(&canvas, at: effect.to, progress: p, count: 12, reach: 32 * effect.power)
    }
}
