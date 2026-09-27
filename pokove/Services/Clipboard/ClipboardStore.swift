import AppKit
import CryptoKit
import ImageIO
import Observation
import UniformTypeIdentifiers

nonisolated struct ClipboardItem: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case text, link, color, image, files
    }

    let id: UUID
    var kind: Kind
    /// What the row shows: the start of the text, the link, or the file names.
    var preview: String
    /// Characters in the full text.
    var length: Int
    /// For files: their paths, for icons and names.
    var paths: [String]
    var pixelSize: CGSize?
    /// A small PNG of a copied image.
    var thumbnail: Data?
    /// The app that was in front when this was copied.
    var sourceBundleID: String?
    var copiedAt: Date
    var isPinned: Bool
    /// Identifies the content, so copying it again moves it up instead of adding a duplicate.
    let digest: String
}

/// Clipboard history: watches the pasteboard and keeps what was copied, so any of it can be
/// copied or pasted again. Pinned items stay on top and survive clearing.
@Observable
final class ClipboardStore {
    /// In display order: pinned first, then newest first.
    private(set) var items: [ClipboardItem] = []
    /// The item on the pasteboard right now, if it came from the history.
    private(set) var currentID: ClipboardItem.ID?

    @ObservationIgnored private let activity: ActivityCenter
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private var lastChangeCount = 0
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var thumbnails: [ClipboardItem.ID: NSImage] = [:]
    @ObservationIgnored private var appIcons: [String: NSImage] = [:]
    @ObservationIgnored private var fileIcons: [String: NSImage] = [:]

    init(activity: ActivityCenter, preferences: Preferences, pasteboard: NSPasteboard = ClipboardStore.defaultPasteboard) {
        self.activity = activity
        self.preferences = preferences
        self.pasteboard = pasteboard
        directory = Self.defaultDirectory
        load()
    }

    static var defaultDirectory: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        #if DEBUG
        let name = "clipboard-debug"
        #else
        let name = "clipboard"
        #endif
        return support.appendingPathComponent("pokove", isDirectory: true).appendingPathComponent(name, isDirectory: true)
    }

    static var defaultPasteboard: NSPasteboard {
        #if DEBUG
        // Lets tests copy into a private pasteboard instead of the real one.
        if let name = UserDefaults.standard.string(forKey: "debugClipboardPasteboard") {
            return NSPasteboard(name: NSPasteboard.Name(name))
        }
        #endif
        return .general
    }

    var unpinnedCount: Int { items.filter { !$0.isPinned }.count }
    var pinnedCount: Int { items.count - unpinnedCount }

    // MARK: Watching

    func start() {
        guard pollTask == nil else { return }
        // What's on the pasteboard at launch joins the history too.
        lastChangeCount = pasteboard.changeCount - 1
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.poll()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        currentID = nil
        guard preferences.clipboardEnabled, let pasteItems = pasteboard.pasteboardItems, !pasteItems.isEmpty else { return }

        let types = Set(pasteItems.flatMap(\.types).map(\.rawValue))
        guard types.isDisjoint(with: Self.privateTypes) else { return }
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let source, Self.privateApps.contains(source) { return }

        var payload: [[String: Data]] = []
        for pasteItem in pasteItems.prefix(100) {
            var entry: [String: Data] = [:]
            for type in Self.keptTypes where pasteItem.types.contains(type) {
                if let data = pasteItem.data(forType: type), data.count <= Self.maxDataSize { entry[type.rawValue] = data }
            }
            if !entry.isEmpty { payload.append(entry) }
        }
        guard !payload.isEmpty else { return }

        // Hashing and thumbnailing an image can take a moment; keep it off the main thread.
        Task { [weak self] in
            let capture = await Task.detached(priority: .utility) { ClipboardCapture(payload: payload) }.value
            guard let self, let capture, self.lastChangeCount == count else { return }
            self.add(capture, source: source)
        }
    }

    private func add(_ capture: ClipboardCapture, source: String?) {
        if let index = items.firstIndex(where: { $0.digest == capture.digest }) {
            items[index].copiedAt = Date()
            items[index].sourceBundleID = source ?? items[index].sourceBundleID
            currentID = items[index].id
        } else {
            let item = ClipboardItem(
                id: UUID(), kind: capture.kind, preview: capture.preview, length: capture.length, paths: capture.paths,
                pixelSize: capture.pixelSize, thumbnail: capture.thumbnail, sourceBundleID: source,
                copiedAt: Date(), isPinned: false, digest: capture.digest
            )
            guard writePayload(capture.payload, for: item.id) else { return }
            items.append(item)
            currentID = item.id
        }
        sortItems()
        trim()
        save()
    }

    // MARK: Actions

    /// Puts an item back on the pasteboard, which also makes it the newest.
    @discardableResult
    func copy(_ id: ClipboardItem.ID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        let item = items[index]
        let payload = readPayload(for: id) ?? (item.kind == .image || item.kind == .files ? nil : [[NSPasteboard.PasteboardType.string.rawValue: Data(item.preview.utf8)]])
        guard let payload else {
            delete(id)
            return false
        }
        let pasteItems = payload.map { entry -> NSPasteboardItem in
            let pasteItem = NSPasteboardItem()
            for (type, data) in entry { pasteItem.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            return pasteItem
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(pasteItems) else { return false }
        lastChangeCount = pasteboard.changeCount
        items[index].copiedAt = Date()
        currentID = id
        sortItems()
        save()
        return true
    }

    /// Copies an item and presses ⌘V in the app in front. Without Accessibility access it is only
    /// copied, and a banner says why.
    func paste(_ id: ClipboardItem.ID) {
        guard copy(id) else { return }
        guard AXIsProcessTrusted() else {
            MediaKeyInterceptor.requestTrust()
            activity.post(NotchBanner(
                style: .clipboard,
                title: String(localized: "Copied"),
                detail: String(localized: "Allow Accessibility for pokove to paste straight into apps."),
                duration: 4
            ))
            return
        }
        Task {
            // Let the notch get out of the way first.
            try? await Task.sleep(for: .milliseconds(180))
            Self.pressPaste()
        }
    }

    func togglePin(_ id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        trim()
        save()
    }

    /// Removes an item. If it is what's on the pasteboard, the pasteboard is cleared as well.
    func delete(_ id: ClipboardItem.ID) {
        items.removeAll { $0.id == id }
        removePayload(for: id)
        if currentID == id { clearPasteboard() }
        save()
    }

    /// Removes everything that isn't pinned.
    func clearHistory() {
        let removed = items.filter { !$0.isPinned }
        guard !removed.isEmpty else { return }
        items.removeAll { !$0.isPinned }
        removed.forEach { removePayload(for: $0.id) }
        if let currentID, removed.contains(where: { $0.id == currentID }) { clearPasteboard() }
        save()
    }

    /// Drops the oldest unpinned items beyond the history size.
    func trim() {
        let limit = max(1, preferences.clipboardLimit)
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > limit else { return }
        let dropped = Set(unpinned.suffix(unpinned.count - limit).map(\.id))
        items.removeAll { dropped.contains($0.id) }
        dropped.forEach(removePayload)
        save()
    }

    private func clearPasteboard() {
        pasteboard.clearContents()
        lastChangeCount = pasteboard.changeCount
        currentID = nil
    }

    private func sortItems() {
        items.sort { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.copiedAt > rhs.copiedAt
        }
    }

    /// ⌘V, as if typed. Key code 9 is the V key's position, whatever the input source.
    private static func pressPaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: Row art

    func thumbnail(for item: ClipboardItem) -> NSImage? {
        if let image = thumbnails[item.id] { return image }
        guard let data = item.thumbnail, let image = NSImage(data: data) else { return nil }
        thumbnails[item.id] = image
        return image
    }

    func appIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = appIcons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleID] = icon
        return icon
    }

    func fileIcon(for path: String) -> NSImage {
        if let icon = fileIcons[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        fileIcons[path] = icon
        return icon
    }

    // MARK: Privacy

    /// Markers password managers and other apps put on copies that shouldn't be kept
    /// (see nspasteboard.org).
    private static let privateTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "org.nspasteboard.TransientType",
        "org.nspasteboard.AutoGeneratedType",
        "com.agilebits.onepassword",
        "de.petermaurer.TransientPasteboardType",
        "com.typeit4me.clipping",
        "Pasteboard generator type",
        "net.antelle.keeweb",
    ]

    private static let privateApps: Set<String> = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
    ]

    private static let keptTypes: [NSPasteboard.PasteboardType] = [.string, .rtf, .html, .png, .tiff, .fileURL, .URL]
    private static let maxDataSize = 24 * 1024 * 1024

    // MARK: Persistence

    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    private func payloadURL(for id: ClipboardItem.ID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("plist")
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        guard let decoded = try? JSONDecoder.clipboard.decode([ClipboardItem].self, from: data) else {
            // Keep an unreadable index instead of overwriting it with an empty history.
            let backup = directory.appendingPathComponent("index-unreadable-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: indexURL, to: backup)
            return
        }
        let fileManager = FileManager.default
        items = decoded.filter { fileManager.fileExists(atPath: payloadURL(for: $0.id).path) }
        sortItems()
        // Payloads no item points to any more.
        let known = Set(items.map { $0.id.uuidString })
        let files = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "plist" && !known.contains(file.deletingPathExtension().lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder.clipboard.encode(items).write(to: indexURL, options: .atomic)
        } catch {
            NSLog("pokove: couldn't save the clipboard history: \(error.localizedDescription)")
        }
    }

    private func writePayload(_ payload: [[String: Data]], for id: ClipboardItem.ID) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            try encoder.encode(payload).write(to: payloadURL(for: id), options: .atomic)
            return true
        } catch {
            NSLog("pokove: couldn't save a clipboard item: \(error.localizedDescription)")
            return false
        }
    }

    private func readPayload(for id: ClipboardItem.ID) -> [[String: Data]]? {
        guard let data = try? Data(contentsOf: payloadURL(for: id)) else { return nil }
        return try? PropertyListDecoder().decode([[String: Data]].self, from: data)
    }

    private func removePayload(for id: ClipboardItem.ID) {
        try? FileManager.default.removeItem(at: payloadURL(for: id))
        thumbnails[id] = nil
    }

    #if DEBUG
    /// Sample history for screenshots, without touching the real pasteboard.
    func debugSeed() {
        let samples: [(ClipboardItem.Kind, String, [String], String?)] = [
            (.text, "let notch = NotchLayout(geometry: geometry, pageCount: pages.count)", [], "com.apple.dt.Xcode"),
            (.link, "https://tryalcove.com/", [], "com.apple.Safari"),
            (.color, "#FF8A5B", [], "com.figma.Desktop"),
            (.text, "회의록: 노치 클립보드 페이지 디자인 리뷰 — 목요일 오후 3시", [], "com.apple.Notes"),
            (.files, "README.md", ["/Users/Shared/README.md"], "com.apple.finder"),
            (.text, "brew install --cask pokove", [], "com.apple.Terminal"),
        ]
        for (offset, sample) in samples.enumerated().reversed() {
            let text = sample.1
            let payload: [[String: Data]] = sample.0 == .files
                ? [[NSPasteboard.PasteboardType.fileURL.rawValue: URL(fileURLWithPath: sample.2[0]).dataRepresentation]]
                : [[NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8)]]
            guard let capture = ClipboardCapture(payload: payload) else { continue }
            let item = ClipboardItem(
                id: UUID(), kind: capture.kind, preview: capture.preview, length: capture.length, paths: capture.paths,
                pixelSize: nil, thumbnail: nil, sourceBundleID: sample.3,
                copiedAt: Date().addingTimeInterval(-Double(offset) * 400 - 20), isPinned: offset == 5, digest: capture.digest
            )
            if items.contains(where: { $0.digest == item.digest }) { continue }
            if writePayload(capture.payload, for: item.id) { items.append(item) }
        }
        sortItems()
        save()
    }
    #endif
}

/// What a copy turns into: its kind, a preview, and the pasteboard data to put back later.
nonisolated struct ClipboardCapture: Sendable {
    var kind: ClipboardItem.Kind
    var preview: String
    var length: Int
    var paths: [String]
    var pixelSize: CGSize?
    var thumbnail: Data?
    var digest: String
    var payload: [[String: Data]]

    init?(payload original: [[String: Data]]) {
        var payload = original
        let stringType = NSPasteboard.PasteboardType.string.rawValue
        let fileURLs = payload.compactMap { entry in
            entry[NSPasteboard.PasteboardType.fileURL.rawValue].flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
        }.filter(\.isFileURL)
        let text = payload.first?[stringType].flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        paths = []
        pixelSize = nil
        thumbnail = nil
        length = 0

        if !fileURLs.isEmpty {
            kind = .files
            paths = fileURLs.prefix(20).map(\.path)
            preview = fileURLs.map(\.lastPathComponent).joined(separator: ", ")
            digest = Self.digest("files", Data(fileURLs.map(\.path).joined(separator: "\n").utf8))
        } else if !trimmed.isEmpty {
            kind = Self.isLink(trimmed) ? .link : (Self.isHexColor(trimmed) ? .color : .text)
            preview = String(trimmed.prefix(400))
            length = text.count
            digest = Self.digest("text", Data(text.utf8))
        } else if let image = Self.imageData(in: &payload) {
            kind = .image
            preview = ""
            let source = CGImageSourceCreateWithData(image as CFData, nil)
            if let source, let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int {
                pixelSize = CGSize(width: width, height: height)
            }
            thumbnail = source.flatMap(Self.thumbnail)
            digest = Self.digest("image", image)
        } else {
            return nil
        }
        self.payload = payload
    }

    private static func digest(_ kind: String, _ data: Data) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(kind.utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// A single-line web or mail address.
    private static func isLink(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), text.count < 2048,
              let url = URL(string: text), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "mailto", "ftp"].contains(scheme) && (url.host != nil || scheme == "mailto")
    }

    private static func isHexColor(_ text: String) -> Bool {
        text.wholeMatch(of: /#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})/) != nil
    }

    /// The image on the pasteboard as PNG. A TIFF-only copy is converted, and TIFF isn't kept
    /// beside a PNG, since it can be many times larger.
    private static func imageData(in payload: inout [[String: Data]]) -> Data? {
        guard var first = payload.first else { return nil }
        let png = NSPasteboard.PasteboardType.png.rawValue
        let tiff = NSPasteboard.PasteboardType.tiff.rawValue
        if let data = first[png] {
            first[tiff] = nil
            payload[0] = first
            return data
        }
        guard let data = first[tiff], let converted = convertToPNG(data) else { return nil }
        first[tiff] = nil
        first[png] = converted
        payload[0] = first
        return converted
    }

    private static func convertToPNG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private static func thumbnail(from source: CGImageSource) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 72,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}

private extension JSONEncoder {
    static var clipboard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var clipboard: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
