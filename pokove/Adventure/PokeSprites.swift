import AppKit
import ImageIO
import SwiftUI

/// Sprites from PokéAPI's sprite repository, downloaded once and kept on disk.
nonisolated enum PokeSpriteKind: String, Sendable {
    /// 40×30 box icon (Gen VII): the dex grid, party slots and the compact notch.
    case icon
    /// Animated battle sprite (Black & White).
    case animated
    /// 96×96 still (Black & White), the fallback when the animation can't be read.
    case still
    /// The party's side of a battle: seen from behind.
    case animatedBack
    case stillBack
    /// Shiny battle sprites. Box icons have no shiny art; those get a `ShinyMark`.
    case animatedShiny
    case stillShiny
    case animatedBackShiny
    case stillBackShiny

    func url(for id: Int) -> URL {
        let path = switch self {
        case .icon: "versions/generation-vii/icons/\(id).png"
        case .animated: "versions/generation-v/black-white/animated/\(id).gif"
        case .still: "versions/generation-v/black-white/\(id).png"
        case .animatedBack: "versions/generation-v/black-white/animated/back/\(id).gif"
        case .stillBack: "versions/generation-v/black-white/back/\(id).png"
        case .animatedShiny: "versions/generation-v/black-white/animated/shiny/\(id).gif"
        case .stillShiny: "versions/generation-v/black-white/shiny/\(id).png"
        case .animatedBackShiny: "versions/generation-v/black-white/animated/back/shiny/\(id).gif"
        case .stillBackShiny: "versions/generation-v/black-white/back/shiny/\(id).png"
        }
        return URL(string: "\(PokeAPI.spriteBase)/\(path)")!
    }

    var fileExtension: String {
        switch self {
        case .animated, .animatedBack, .animatedShiny, .animatedBackShiny: "gif"
        default: "png"
        }
    }

    /// The animated and still sprites for a side and coloring.
    static func battle(back: Bool, shiny: Bool) -> (animated: PokeSpriteKind, still: PokeSpriteKind) {
        switch (back, shiny) {
        case (false, false): (.animated, .still)
        case (true, false): (.animatedBack, .stillBack)
        case (false, true): (.animatedShiny, .stillShiny)
        case (true, true): (.animatedBackShiny, .stillBackShiny)
        }
    }
}

/// Decoded frames of a sprite, cropped to what's drawn.
final class PokeImage {
    let frames: [CGImage]
    /// Seconds each frame stays up.
    let delays: [Double]
    let duration: Double
    /// Pixel size of every frame.
    let size: CGSize

    init?(data: Data, crop: Bool) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        var frames: [CGImage] = []
        var delays: [Double] = []
        for index in 0..<count {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(image)
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            delays.append(delay < 0.02 ? 0.1 : delay)
        }
        guard !frames.isEmpty else { return nil }
        if crop, let box = Self.opaqueBounds(of: frames) {
            frames = frames.compactMap { $0.cropping(to: box) }
        }
        self.frames = frames
        self.delays = delays
        duration = delays.reduce(0, +)
        size = CGSize(width: frames[0].width, height: frames[0].height)
    }

    func frame(at time: TimeInterval) -> CGImage {
        guard frames.count > 1, duration > 0 else { return frames[0] }
        var t = time.truncatingRemainder(dividingBy: duration)
        for (index, delay) in delays.enumerated() {
            if t < delay { return frames[index] }
            t -= delay
        }
        return frames[frames.count - 1]
    }

    /// The smallest box holding every opaque pixel across all frames, so padding never throws
    /// off the layout.
    private static func opaqueBounds(of frames: [CGImage]) -> CGRect? {
        let width = frames[0].width, height = frames[0].height
        var minX = width, minY = height, maxX = -1, maxY = -1
        for frame in frames where frame.width == width && frame.height == height {
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { continue }
            context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 8 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // CGContext rows run bottom-up; cropping works top-down.
        return CGRect(x: minX, y: height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

/// Memory and disk cache for sprites, with in-flight downloads shared.
final class PokeSpriteCache {
    static let shared = PokeSpriteCache()

    private var images: [String: PokeImage] = [:]
    private var inflight: [String: Task<PokeImage?, Never>] = [:]
    private let directory = PokeDexStore.defaultDirectory.appendingPathComponent("sprites", isDirectory: true)

    private func key(_ kind: PokeSpriteKind, _ id: Int) -> String { "\(kind.rawValue)-\(id)" }

    func cached(_ kind: PokeSpriteKind, _ id: Int) -> PokeImage? { images[key(kind, id)] }

    func image(_ kind: PokeSpriteKind, _ id: Int) async -> PokeImage? {
        // Icons keep their 40×30 canvas so the grid lines up; battle sprites are cropped.
        await image(url: kind.url(for: id), key: key(kind, id), fileExtension: kind.fileExtension, crop: kind != .icon)
    }

    /// A gym leader or League trainer, from Showdown's FireRed/LeafGreen-style sprites.
    func trainer(_ slug: String) async -> PokeImage? {
        guard let url = URL(string: "\(PokeAPI.trainerBase)/\(slug).png") else { return nil }
        return await image(url: url, key: "trainer-\(slug)", fileExtension: "png", crop: true)
    }

    /// A bag item, such as a Poké Ball.
    func item(_ slug: String) async -> PokeImage? {
        guard let url = URL(string: "\(PokeAPI.itemBase)/\(slug).png") else { return nil }
        return await image(url: url, key: "item-\(slug)", fileExtension: "png", crop: true)
    }

    func badge(_ number: Int) async -> PokeImage? {
        guard let url = URL(string: "\(PokeAPI.badgeBase)/\(number).png") else { return nil }
        return await image(url: url, key: "badge-\(number)", fileExtension: "png", crop: false)
    }

    func cached(key: String) -> PokeImage? { images[key] }

    private func image(url: URL, key: String, fileExtension: String, crop: Bool) async -> PokeImage? {
        if let image = images[key] { return image }
        if let task = inflight[key] { return await task.value }
        let file = directory.appendingPathComponent(key).appendingPathExtension(fileExtension)
        let directory = directory
        let task = Task<PokeImage?, Never> {
            let data: Data? = await Task.detached(priority: .utility) {
                if let data = try? Data(contentsOf: file) { return data }
                guard let (data, response) = try? await URLSession.shared.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { return nil }
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try? data.write(to: file, options: .atomic)
                return data
            }.value
            guard let data else { return nil }
            return PokeImage(data: data, crop: crop)
        }
        inflight[key] = task
        let image = await task.value
        inflight[key] = nil
        if let image { images[key] = image }
        return image
    }

    /// Downloads every icon in the background, so silhouettes fill in without scrolling.
    func prefetchIcons(upTo maxID: Int) {
        Task {
            for id in 1...maxID where images[key(.icon, id)] == nil {
                _ = await image(.icon, id)
            }
        }
    }
}

// MARK: Views

/// A box icon at whole-pixel scale. Uncaught species show as a flat silhouette.
struct PokeIconView: View {
    let id: Int
    /// Points per sprite pixel. Use multiples of 0.5 so pixels stay square on Retina.
    var pixelSize: CGFloat = 1
    var silhouette = false
    var silhouetteOpacity = 0.14

    @State private var image: PokeImage?

    var body: some View {
        let shown = image ?? PokeSpriteCache.shared.cached(.icon, id)
        Group {
            if let shown {
                let picture = Image(decorative: shown.frames[0], scale: 1)
                    .interpolation(.none)
                    .resizable()
                if silhouette {
                    picture.renderingMode(.template).foregroundStyle(.white.opacity(silhouetteOpacity))
                } else {
                    picture
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 40 * pixelSize, height: 30 * pixelSize)
        .task(id: id) {
            image = await PokeSpriteCache.shared.image(.icon, id)
        }
    }
}

/// An animated battle sprite, facing left as in the games unless `flipped`, or seen from behind.
struct PokeSpriteView: View {
    let id: Int
    var pixelSize: CGFloat = 0.5
    var flipped = false
    var silhouette = false
    var back = false
    var shiny = false
    /// Big Pokémon shrink to fit this height, in quarter-point steps.
    var fitHeight: CGFloat?

    @State private var image: PokeImage?

    var body: some View {
        Group {
            if let image {
                let scale = Self.scale(for: image, pixelSize: pixelSize, fitHeight: fitHeight)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: image.frames.count < 2)) { context in
                    let frame = Image(decorative: image.frame(at: context.date.timeIntervalSinceReferenceDate), scale: 1)
                        .interpolation(.none)
                        .resizable()
                    Group {
                        if silhouette {
                            frame.renderingMode(.template).foregroundStyle(.black.opacity(0.85))
                        } else {
                            frame
                        }
                    }
                    .frame(width: image.size.width * scale, height: image.size.height * scale)
                    .scaleEffect(x: flipped ? -1 : 1, y: 1)
                }
            } else {
                Color.clear.frame(width: 40 * pixelSize * 2, height: 40 * pixelSize * 2)
            }
        }
        .task(id: "\(id)-\(back)-\(shiny)") {
            let cache = PokeSpriteCache.shared
            // A shiny without art falls back to the usual colors.
            let plain = PokeSpriteKind.battle(back: back, shiny: false)
            let kinds = shiny ? [PokeSpriteKind.battle(back: back, shiny: true), plain] : [plain]
            if let first = kinds.first, let known = cache.cached(first.animated, id) ?? cache.cached(first.still, id) {
                image = known
                return
            }
            for kind in kinds {
                if let loaded = await cache.image(kind.animated, id) { image = loaded; return }
                if let loaded = await cache.image(kind.still, id) { image = loaded; return }
            }
        }
    }

    static func scale(for image: PokeImage, pixelSize: CGFloat, fitHeight: CGFloat?) -> CGFloat {
        guard let fitHeight, image.size.height * pixelSize > fitHeight else { return pixelSize }
        return max(0.5, (fitHeight / image.size.height * 4).rounded(.down) / 4)
    }
}

/// The ✦ on a shiny Pokémon's box icon, which has no shiny art of its own.
struct ShinyMark: View {
    var size: CGFloat = 8

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(Color(hex: 0xFFE14D))
            .shadow(color: .black.opacity(0.85), radius: 0, x: 0.6, y: 0.6)
            .accessibilityLabel(Text(verbatim: RecapText.shinyLabel))
    }
}

/// A trainer's sprite at whole-pixel scale.
struct TrainerSpriteView: View {
    let slug: String
    var pixelSize: CGFloat = 0.5

    @State private var image: PokeImage?

    var body: some View {
        let shown = image ?? PokeSpriteCache.shared.cached(key: "trainer-\(slug)")
        Group {
            if let shown {
                Image(decorative: shown.frames[0], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: shown.size.width * pixelSize, height: shown.size.height * pixelSize)
            } else {
                Color.clear.frame(width: 60 * pixelSize, height: 70 * pixelSize)
            }
        }
        .task(id: slug) { image = await PokeSpriteCache.shared.trainer(slug) }
    }
}

/// A bag item's sprite at whole-pixel scale.
struct ItemSpriteView: View {
    let slug: String
    var pixelSize: CGFloat = 1

    @State private var image: PokeImage?

    var body: some View {
        let shown = image ?? PokeSpriteCache.shared.cached(key: "item-\(slug)")
        Group {
            if let shown {
                Image(decorative: shown.frames[0], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: shown.size.width * pixelSize, height: shown.size.height * pixelSize)
            } else {
                Circle().fill(.white.opacity(0.08)).frame(width: 22 * pixelSize, height: 22 * pixelSize)
            }
        }
        .task(id: slug) { image = await PokeSpriteCache.shared.item(slug) }
    }
}

/// A gym badge, smoothly scaled (the art isn't pixel art). Unearned badges show as a dim silhouette.
struct BadgeImageView: View {
    /// PokéAPI's badge number: Kanto's 1–8, Johto's 9–16 (`Region.badgeImage`).
    let number: Int
    var size: CGFloat = 16
    var earned = true
    var unearnedColor: Color = .white.opacity(0.14)

    @State private var image: PokeImage?

    var body: some View {
        let shown = image ?? PokeSpriteCache.shared.cached(key: "badge-\(number)")
        Group {
            if let shown {
                let picture = Image(decorative: shown.frames[0], scale: 1).resizable().interpolation(.high)
                if earned {
                    picture.aspectRatio(contentMode: .fit)
                } else {
                    picture.renderingMode(.template).aspectRatio(contentMode: .fit).foregroundStyle(unearnedColor)
                }
            } else {
                Circle().fill(.white.opacity(0.08))
            }
        }
        .frame(width: size, height: size)
        .task(id: number) { image = await PokeSpriteCache.shared.badge(number) }
    }
}

extension PokeType {
    var color: Color { Color(hex: hex) }
}

/// A small pill with the type's name in its color.
struct PokeTypeBadge: View {
    let type: PokeType
    var compact = false

    var body: some View {
        Text(type.title)
            .font(.system(size: compact ? 8.5 : 9.5, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : 5.5)
            .padding(.vertical, compact ? 1 : 1.5)
            .background(type.color.opacity(0.85), in: Capsule())
    }
}
