import SwiftUI

/// The fishing page: a pixel fishing spot that comes alive while Claude works, and the collection.
struct FishingPageView: View {
    @Environment(AppModel.self) private var app
    @State private var selection: String?

    var body: some View {
        let fishing = app.fishing
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    if let id = selection, let species = FishCatalog.species(id: id) {
                        FishDetailCard(species: species, entry: fishing.entry(for: species)) {
                            selection = nil
                        }
                        .id(id)
                        .transition(.blurReplace)
                    } else {
                        FishingSceneView()
                            .transition(.blurReplace)
                    }
                }
                .frame(width: FishingSceneView.size.width, height: FishingSceneView.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08)))
                .animation(.smooth(duration: 0.28), value: selection)

                FishingStatusLine()
                    .frame(width: FishingSceneView.size.width, alignment: .leading)
            }

            CollectionGrid(selection: $selection)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .dancoveDebugSelectFish)) { note in
            selection = note.object as? String
        }
        #endif
    }
}

#if DEBUG
extension Notification.Name {
    static let dancoveDebugSelectFish = Notification.Name("dancoveDebugSelectFish")
}
#endif

// MARK: Status

private struct FishingStatusLine: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let fishing = app.fishing
        HStack(spacing: 5) {
            if let cast = fishing.oldestCast, fishing.isFishing {
                Image(systemName: "figure.fishing")
                    .foregroundStyle(Color(hex: 0x8FD0FF))
                Text("Fishing")
                    .foregroundStyle(.white.opacity(0.85))
                Text(timerInterval: cast.startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                let nibbles = fishing.casts.values.reduce(0) { $0 + $1.nibbles }
                if nibbles > 0 {
                    Text("· \(nibbles) nibbles")
                        .foregroundStyle(.white.opacity(0.45))
                        .contentTransition(.numericText())
                }
            } else if let miss = missMessage(fishing.lastOutcome) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.white.opacity(0.4))
                Text(miss)
                    .foregroundStyle(.white.opacity(0.5))
            } else if let last = fishing.recent.first, let species = last.species {
                Text("Last catch")
                    .foregroundStyle(.white.opacity(0.45))
                Text(species.name)
                    .foregroundStyle(species.rarity.color)
                Text(FishCatch.format(size: last.size))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
            } else {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.white.opacity(0.4))
                Text("Casts when Claude starts working")
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .animation(.smooth(duration: 0.25), value: fishing.isFishing)
    }

    /// Why the last line came back empty, if it did.
    private func missMessage(_ outcome: FishingService.Outcome?) -> String? {
        switch outcome {
        case .escaped: String(localized: "The fish got away")
        case .snapped: String(localized: "The line snapped")
        case .tooQuick: String(localized: "Too quick for a bite")
        case .caught, nil: nil
        }
    }
}

// MARK: Scene

/// A 98×59 pixel fishing spot at 2 pt per pixel. The sky follows the real time of day.
struct FishingSceneView: View {
    static let pixel: CGFloat = 2
    static let grid = (width: 98, height: 59)
    static var size: CGSize { CGSize(width: CGFloat(grid.width) * pixel, height: CGFloat(grid.height) * pixel) }

    @Environment(AppModel.self) private var app
    @State private var nibbleAt: Date?
    @State private var catchAt: Date?

    var body: some View {
        let fishing = app.fishing
        let isFishing = fishing.isFishing
        let landed = fishing.recent.first
        let palette = ScenePalette.current(at: .now)
        ZStack {
            // The still layer (sky, islands, water, dock) renders once; only the live layer ticks.
            Canvas { canvas, _ in
                SceneRenderer(canvas: canvas, time: 0, palette: palette, isFishing: isFishing,
                              sinceNibble: .infinity, sinceCatch: .infinity, landed: nil)
                    .drawBackground()
            }
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                Canvas { canvas, _ in
                    SceneRenderer(
                        canvas: canvas,
                        time: context.date.timeIntervalSinceReferenceDate,
                        palette: palette,
                        isFishing: isFishing,
                        sinceNibble: nibbleAt.map { context.date.timeIntervalSince($0) } ?? .infinity,
                        sinceCatch: catchAt.map { context.date.timeIntervalSince($0) } ?? .infinity,
                        landed: landed?.species
                    )
                    .drawForeground()
                }
            }
        }
        .onChange(of: fishing.nibbleTick) { nibbleAt = Date() }
        .onChange(of: fishing.recent.first?.id) { _, id in if id != nil { catchAt = Date() } }
        .accessibilityLabel(Text(isFishing ? "Fishing while Claude works" : "Fishing spot"))
    }
}

private struct ScenePalette {
    var skyTop: UInt32
    var skyBottom: UInt32
    var hills: UInt32
    var water: (UInt32, UInt32, UInt32)
    var shimmer: UInt32
    var isNight: Bool
    var hasClouds: Bool

    static func current(at date: Date) -> ScenePalette {
        var hour = Calendar.current.component(.hour, from: date)
        #if DEBUG
        if let override = UserDefaults.standard.object(forKey: "debugSceneHour") as? Int { hour = override }
        #endif
        return switch hour {
        case 5..<7:
            ScenePalette(skyTop: 0x2A3A7A, skyBottom: 0xF2A68A, hills: 0x3A2E5A, water: (0x5A6AA8, 0x3E4E8A, 0x28346A),
                         shimmer: 0xFFD2B8, isNight: false, hasClouds: true)
        case 7..<17:
            ScenePalette(skyTop: 0x3A86E0, skyBottom: 0xAEDCFF, hills: 0x3E8A6A, water: (0x2E7ED0, 0x2262B0, 0x184A8A),
                         shimmer: 0xD8F4FF, isNight: false, hasClouds: true)
        case 17..<20:
            ScenePalette(skyTop: 0x2C2A6A, skyBottom: 0xF28A5A, hills: 0x40284A, water: (0x4A4A8A, 0x36346E, 0x221E50),
                         shimmer: 0xFFC08A, isNight: false, hasClouds: true)
        default:
            ScenePalette(skyTop: 0x090D26, skyBottom: 0x223066, hills: 0x0E1430, water: (0x1C3272, 0x132458, 0x0B1740),
                         shimmer: 0x7A9AE8, isNight: true, hasClouds: false)
        }
    }
}

/// Draws the scene in grid pixels. Everything snaps to the 2 pt grid, so it reads as pixel art.
private struct SceneRenderer {
    let canvas: GraphicsContext
    let time: TimeInterval
    let palette: ScenePalette
    let isFishing: Bool
    let sinceNibble: TimeInterval
    let sinceCatch: TimeInterval
    let landed: FishSpecies?

    let width = FishingSceneView.grid.width
    let height = FishingSceneView.grid.height
    let horizon = 30
    let bobberX = 62

    func drawBackground() {
        drawSky()
        drawWater()
        drawDock()
    }

    func drawForeground() {
        drawSkyLife()
        drawWaterLife()
        drawAngler()
        if sinceCatch < 2.4, let landed { drawLeap(landed) }
    }

    private func px(_ x: Int, _ y: Int, _ color: UInt32, opacity: Double = 1, w: Int = 1, h: Int = 1) {
        let p = FishingSceneView.pixel
        canvas.fill(
            Path(CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: CGFloat(w) * p, height: CGFloat(h) * p)),
            with: .color(Color(hex: color, opacity: opacity))
        )
    }

    private func sprite(_ key: String, _ sprite: PixelSprite, x: Int, y: Int, opacity: Double = 1) {
        guard let image = SpriteCache.image(key, sprite: sprite) else { return }
        let p = FishingSceneView.pixel
        var canvas = canvas
        canvas.opacity = opacity
        canvas.draw(
            Image(decorative: image, scale: 1).interpolation(.none),
            in: CGRect(x: CGFloat(x) * p, y: CGFloat(y) * p, width: CGFloat(image.width) * p, height: CGFloat(image.height) * p)
        )
    }

    // MARK: Sky

    private func drawSky() {
        // Banded gradient with a dithered seam between bands, the classic 16-bit sky.
        let bands = 6
        let bandHeight = Double(horizon) / Double(bands)
        for band in 0..<bands {
            let color = PixelSprite.mix(palette.skyTop, palette.skyBottom, Double(band) / Double(bands - 1))
            let top = Int((Double(band) * bandHeight).rounded())
            let bottom = Int((Double(band + 1) * bandHeight).rounded())
            px(0, top, color, w: width, h: bottom - top)
            if band + 1 < bands {
                let next = PixelSprite.mix(palette.skyTop, palette.skyBottom, Double(band + 1) / Double(bands - 1))
                for x in stride(from: bottom % 2, to: width, by: 2) { px(x, bottom - 1, next) }
            }
        }

        // Distant islands along the horizon.
        for x in 38..<width {
            let rise = 2.6 * sin(Double(x - 38) / 7.5) + 1.8 * sin(Double(x) / 3.1)
            let h = max(0, Int(rise.rounded()))
            if h > 0 { px(x, horizon - h, palette.hills, h: h) }
        }
    }

    private func drawSkyLife() {
        if palette.isNight {
            for (index, star) in Self.stars.enumerated() {
                let twinkle = 0.45 + 0.55 * max(0, sin(time * (1.2 + Double(index % 4) * 0.4) + Double(index)))
                px(star.0, star.1, 0xFFFFFF, opacity: twinkle)
            }
            sprite("moon", FishingArt.moon, x: 80, y: 4)
        } else {
            sprite("sun", FishingArt.sun, x: 80, y: 4)
        }
        if palette.hasClouds {
            for (index, base) in [(8, 5), (46, 10), (70, 3)].enumerated() {
                let span = width + 14
                let x = (Int(Double(base.0) + time * (0.8 + Double(index) * 0.3)) % span) - 12
                sprite("cloud", FishingArt.cloud, x: x, y: base.1)
            }
        }
    }

    private static let stars: [(Int, Int)] = [
        (4, 3), (13, 9), (22, 2), (30, 12), (37, 5), (48, 2), (55, 8), (63, 4), (71, 11), (91, 3), (94, 14), (58, 15), (18, 16),
    ]

    // MARK: Water

    private func drawWater() {
        px(0, horizon, palette.water.0, w: width, h: 5)
        px(0, horizon + 5, palette.water.1, w: width, h: 11)
        px(0, horizon + 16, palette.water.2, w: width, h: height - horizon - 16)
        for x in stride(from: 0, to: width, by: 2) {
            px(x + (horizon + 5) % 2, horizon + 5, palette.water.0)
            px(x + (horizon + 16) % 2, horizon + 16, palette.water.1)
        }
    }

    private func drawWaterLife() {
        // Rolling crests along the surface.
        let shift = Int(time * 5)
        for x in 0..<width where (x + shift) % 7 < 2 {
            px(x, horizon, palette.shimmer, opacity: 0.8)
        }
        // Glints drifting across the water.
        for index in 0..<9 {
            let speed = 1.2 + Double(index % 3) * 0.7
            let x = Int(Double(index * 23) + time * speed) % (width + 6) - 3
            let y = horizon + 3 + (index * 7) % (height - horizon - 5)
            let blink = sin(time * 2 + Double(index) * 1.3)
            if blink > -0.2 { px(x, y, palette.shimmer, opacity: 0.55, w: 2 + index % 2) }
        }
        if palette.isNight {
            // The moon's reflection, wobbling.
            for row in 0..<7 {
                let y = horizon + 2 + row * 3
                let wobble = Int((sin(time * 3 + Double(row)) * 1.5).rounded())
                px(81 + wobble - row % 2, y, 0xFFF4C8, opacity: 0.55 - Double(row) * 0.06, w: 3 - row % 2)
            }
        }

        // Ripples around the float after a nibble.
        if isFishing && sinceNibble < 0.9 {
            let radius = 2 + Int(sinceNibble * 9)
            let opacity = 1 - sinceNibble / 0.9
            px(bobberX + 2 - radius, horizon + 1, 0xFFFFFF, opacity: opacity, w: 2)
            px(bobberX + 1 + radius, horizon + 1, 0xFFFFFF, opacity: opacity, w: 2)
        }
    }

    // MARK: Dock and angler

    private func drawDock() {
        let plank: UInt32 = 0x8A5A34, edge: UInt32 = 0x5A3820, post: UInt32 = 0x4A2E1A
        px(3, 27, post, w: 2, h: 16)
        px(19, 27, post, w: 2, h: 16)
        px(0, 25, plank, w: 26, h: 2)
        px(0, 27, edge, w: 26, h: 1)
        for x in stride(from: 4, to: 26, by: 6) { px(x, 25, edge) }
        // Posts sink below the waterline.
        px(3, horizon, palette.water.0, opacity: 0.55, w: 2, h: 13)
        px(19, horizon, palette.water.0, opacity: 0.55, w: 2, h: 13)
    }

    private func drawAngler() {
        let catSprite = isFishing ? FishingArt.cat : FishingArt.sleepingCat
        sprite(isFishing ? "cat" : "cat-sleep", catSprite, x: 7, y: 13)

        // Rod from the cat's paws to the tip.
        let rod: [(Int, Int)] = (0...14).map { step in (19 + step, 21 - Int((Double(step) * 0.9).rounded())) }
        for (index, point) in rod.enumerated() {
            px(point.0, point.1, index < 4 ? 0x6A4424 : 0xC8A060)
        }
        let tip = rod.last!

        let bob = sin(time * 2.6) * 0.8
        let dip = isFishing && sinceNibble < 0.6 ? sin(min(1, sinceNibble / 0.6) * .pi) * 2.5 : 0
        let floatY = isFishing ? Double(horizon - 4) + bob + dip : Double(tip.1 + 9)
        let floatX = isFishing ? bobberX : tip.0 - 2

        // Fishing line with a little sag.
        let p = FishingSceneView.pixel
        var line = Path()
        let start = CGPoint(x: (CGFloat(tip.0) + 0.5) * p, y: (CGFloat(tip.1) + 0.5) * p)
        let end = CGPoint(x: (CGFloat(floatX) + 2.5) * p, y: CGFloat(floatY + 0.5) * p)
        line.move(to: start)
        line.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(start.y, end.y) - 2))
        canvas.stroke(line, with: .color(.white.opacity(0.45)), lineWidth: 0.75)

        sprite("bobber", FishingArt.bobber, x: floatX, y: Int(floatY.rounded()))

        if !isFishing {
            // Z's drifting up from the dozing cat.
            let cycle = time.truncatingRemainder(dividingBy: 3) / 3
            let rise = Int(cycle * 8)
            px(16 + rise / 3, 10 - rise, 0xFFFFFF, opacity: 1 - cycle, w: 2)
            px(17 + rise / 3, 11 - rise, 0xFFFFFF, opacity: 1 - cycle)
            px(16 + rise / 3, 12 - rise, 0xFFFFFF, opacity: 1 - cycle, w: 2)
        }
    }

    /// The catch leaps out of the water beside the float.
    private func drawLeap(_ species: FishSpecies) {
        let duration = 1.4
        let progress = min(1, sinceCatch / duration)
        let arc = sin(progress * .pi)
        let x = bobberX - 14 - Int(progress * 10)
        let y = horizon - 12 - Int((arc * 16).rounded())
        if progress < 1 {
            sprite(species.id, species.sprite, x: x, y: y)
        }
        // Splashes where it leaves and re-enters the water.
        for (moment, splashX) in [(0.0, bobberX - 6), (1.0, bobberX - 18)] where abs(progress - moment) < 0.18 {
            for dx in [-3, -1, 1, 3] { px(splashX + dx, horizon - 1 - abs(dx) / 2, 0xFFFFFF, opacity: 0.9) }
        }
        if progress >= 1 {
            // Show off the catch above the dock for a moment.
            let fade = max(0, 1 - (sinceCatch - duration) / 1.0)
            sprite(species.id, species.sprite, x: 30, y: 2, opacity: fade)
        }
    }
}

// MARK: Collection

private struct CollectionGrid: View {
    @Binding var selection: String?
    @Environment(AppModel.self) private var app

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 5)
    /// A hovered cell scales up by 6%; this leaves it room on every side.
    private static let growRoom: CGFloat = 4

    var body: some View {
        let fishing = app.fishing
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Collection")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(fishing.caughtSpeciesCount)/\(FishCatalog.all.count)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText())
            }
            RarityProgressBar()
                .frame(height: 4)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(FishCatalog.all) { species in
                        FishCell(species: species, entry: fishing.entry(for: species), isSelected: selection == species.id) {
                            selection = selection == species.id ? nil : species.id
                        }
                    }
                }
                // Room for a hovered cell to grow without the scroll view clipping its edges.
                .padding(.horizontal, Self.growRoom)
                .padding(.top, Self.growRoom + 2)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, -Self.growRoom)
            .padding(.top, -Self.growRoom)
            .mask {
                // Soft bottom edge hints that the collection scrolls; the top fades only inside
                // the grow room, so the first row stays whole.
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.growRoom)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                }
            }
        }
        .frame(width: 5 * 40 + 4 * 4)
    }
}

/// Collection progress split by rarity, each segment as wide as its share of the catalog.
private struct RarityProgressBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        GeometryReader { proxy in
            let total = CGFloat(FishCatalog.all.count)
            HStack(spacing: 2) {
                ForEach(FishRarity.allCases) { rarity in
                    let pool = CGFloat(FishCatalog.species(of: rarity).count)
                    let caught = CGFloat(app.fishing.caughtCount(of: rarity))
                    let width = (proxy.size.width - 10) * pool / total
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(rarity.color)
                            .frame(width: width * caught / max(1, pool))
                    }
                    .frame(width: width)
                }
            }
        }
        .animation(.smooth, value: app.fishing.caughtSpeciesCount)
    }
}

private struct FishCell: View {
    let species: FishSpecies
    let entry: FishingService.Entry?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let caught = entry != nil
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(caught ? species.rarity.color.opacity(isHovering ? 0.2 : 0.11) : .white.opacity(isHovering ? 0.09 : 0.045))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? .white.opacity(0.7) : (caught ? species.rarity.color.opacity(0.35) : .clear),
                        lineWidth: isSelected ? 1.5 : 1
                    )
                // 24×16 sprites at 1.5 pt per pixel: three Retina pixels per dot.
                FishSpriteView(species: species, pixelSize: 1.5, silhouette: !caught)
                    .opacity(caught ? 1 : 0.13)
                if !caught {
                    Text("?")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 40, height: 30)
            .scaleEffect(isHovering ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(caught ? species.name : String(localized: "Not caught yet"))
    }
}

/// Details for the selected fish, shown where the scene was.
private struct FishDetailCard: View {
    let species: FishSpecies
    let entry: FishingService.Entry?
    let close: () -> Void

    var body: some View {
        let caught = entry != nil
        ZStack(alignment: .topTrailing) {
            Rectangle().fill(Color(hex: 0x101218))
            if caught { RarityAura(rarity: species.rarity, intensity: 0.8).offset(x: -50, y: -10) }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    FishSpriteView(species: species, pixelSize: 2.5, silhouette: !caught)
                        .opacity(caught ? 1 : 0.16)
                        .frame(width: 60, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(caught ? species.name : "???")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        RarityLabel(rarity: species.rarity, size: 10)
                        if let entry {
                            Text("×\(entry.count) · best \(FishCatch.format(size: entry.bestSize))")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                }
                Text(caught ? species.blurb : String(localized: "Keep Claude busy to meet this one."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(caught ? 0.7 : 0.45))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let entry {
                    Text("First caught \(entry.firstCaughtAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(7)
        }
    }
}
