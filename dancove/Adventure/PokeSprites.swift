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

    func url(for id: Int) -> URL {
        let path = switch self {
        case .icon: "versions/generation-vii/icons/\(id).png"
        case .animated: "versions/generation-v/black-white/animated/\(id).gif"
        case .still: "versions/generation-v/black-white/\(id).png"
        }
        return URL(string: "\(PokeAPI.spriteBase)/\(path)")!
    }

    var fileExtension: String { self == .animated ? "gif" : "png" }
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
        let key = key(kind, id)
        if let image = images[key] { return image }
        if let task = inflight[key] { return await task.value }
        let file = directory.appendingPathComponent(key).appendingPathExtension(kind.fileExtension)
        let url = kind.url(for: id)
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
            // Icons keep their 40×30 canvas so the grid lines up; battle sprites are cropped.
            return PokeImage(data: data, crop: kind != .icon)
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

/// An animated battle sprite, facing left as in the games unless `flipped`.
struct PokeSpriteView: View {
    let id: Int
    var pixelSize: CGFloat = 0.5
    var flipped = false
    var silhouette = false

    @State private var image: PokeImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
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
                    .frame(width: image.size.width * pixelSize, height: image.size.height * pixelSize)
                    .scaleEffect(x: flipped ? -1 : 1, y: 1)
                }
            } else {
                Color.clear.frame(width: 40 * pixelSize * 2, height: 40 * pixelSize * 2)
            }
        }
        .task(id: id) {
            image = PokeSpriteCache.shared.cached(.animated, id) ?? PokeSpriteCache.shared.cached(.still, id)
            guard image == nil else { return }
            if let animated = await PokeSpriteCache.shared.image(.animated, id) {
                image = animated
            } else {
                image = await PokeSpriteCache.shared.image(.still, id)
            }
        }
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
