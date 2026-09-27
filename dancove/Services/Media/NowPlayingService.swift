import AppKit
import Observation

/// Now-playing state for whatever app currently owns system media (Music, Spotify, browsers…).
///
/// Reads come from the bundled MediaRemote bridge running inside `/usr/bin/perl`
/// (see `MediaRemoteAdapter/`); commands are written to the same process over stdin.
@Observable
final class NowPlayingService {
    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
    }

    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var duration: TimeInterval = 0
    private(set) var artwork: NSImage?
    /// Artwork-derived tint for the visualizer and scrubber.
    private(set) var accentColor: NSColor = .white
    private(set) var sourceBundleID: String?
    private(set) var sourceIcon: NSImage?
    private(set) var isAvailable = true
    /// When playback last stopped, so the live activity can linger briefly after a pause.
    private(set) var pausedAt: Date?

    /// Called when a different track starts (not on the first report).
    @ObservationIgnored var onTrackChange: (() -> Void)?
    /// Called when playback starts or stops.
    @ObservationIgnored var onPlaybackChange: ((Bool) -> Void)?

    @ObservationIgnored private var lastTrack: (track: Track, seenAt: Date)?
    @ObservationIgnored private var elapsedAnchor: TimeInterval = 0
    @ObservationIgnored private var anchorDate = Date()
    @ObservationIgnored private var playbackRate: Double = 1
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var lineBuffer = Data()
    @ObservationIgnored private var restartAttempts = 0
    @ObservationIgnored private var isStopping = false

    var hasMedia: Bool { track != nil }

    /// Playback position interpolated from the last report.
    func elapsed(at date: Date = .now) -> TimeInterval {
        guard isPlaying else { return min(elapsedAnchor, duration > 0 ? duration : .greatestFiniteMagnitude) }
        let value = elapsedAnchor + date.timeIntervalSince(anchorDate) * playbackRate
        return duration > 0 ? min(max(0, value), duration) : max(0, value)
    }

    // MARK: Lifecycle

    func start() {
        guard process == nil else { return }
        isStopping = false
        guard let script = Bundle.main.url(forResource: "dancove-mediaremote", withExtension: "pl"),
              let library = Bundle.main.url(forResource: "libDancoveMediaRemote", withExtension: "dylib") else {
            isAvailable = false
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [script.path, library.path, "stream"]
        let stdout = Pipe()
        let stdin = Pipe()
        process.standardOutput = stdout
        process.standardInput = stdin
        process.standardError = FileHandle.nullDevice

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                // EOF: the helper exited. Without this the handler would spin on empty reads.
                handle.readabilityHandler = nil
                return
            }
            DispatchQueue.main.async {
                self?.consume(data)
            }
        }
        process.terminationHandler = { [weak self] ended in
            let status = ended.terminationStatus
            let id = ObjectIdentifier(ended)
            DispatchQueue.main.async {
                self?.handleTermination(of: id, status: status)
            }
        }

        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }

    func stop() {
        isStopping = true
        try? input?.close()
        process?.terminate()
        process = nil
        input = nil
    }

    private func handleTermination(of ended: ObjectIdentifier, status: Int32) {
        // A late callback from a process we already replaced must not clear the new one.
        guard let process, ObjectIdentifier(process) == ended else { return }
        self.process = nil
        input = nil
        guard !isStopping else { return }
        if status == 2 {
            // MediaRemote refused to load; don't spin.
            isAvailable = false
            return
        }
        restartAttempts += 1
        guard restartAttempts <= 5 else {
            isAvailable = false
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(Double(restartAttempts)))
            start()
        }
    }

    // MARK: Commands

    func togglePlayPause() {
        send("command 2")
        // Optimistic update so the button flips immediately.
        if isPlaying { markPaused() } else { markPlaying() }
    }

    func nextTrack() { send("command 4") }
    func previousTrack() { send("command 5") }

    func seek(to position: TimeInterval) {
        send("seek \(position)")
        elapsedAnchor = position
        anchorDate = .now
    }

    private func send(_ line: String) {
        guard let input else { return }
        try? input.write(contentsOf: Data((line + "\n").utf8))
    }

    private func markPaused() {
        elapsedAnchor = elapsed()
        anchorDate = .now
        isPlaying = false
        pausedAt = .now
        onPlaybackChange?(false)
    }

    private func markPlaying() {
        anchorDate = .now
        isPlaying = true
        pausedAt = nil
        onPlaybackChange?(true)
    }

    // MARK: Parsing

    private func consume(_ data: Data) {
        guard !data.isEmpty else { return }
        lineBuffer.append(data)
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer[lineBuffer.startIndex..<newline]
            lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            apply(object)
        }
    }

    private func apply(_ state: [String: Any]) {
        restartAttempts = 0
        guard state["type"] as? String == "state", let title = state["title"] as? String else {
            clear()
            return
        }

        let newTrack = Track(
            title: title,
            artist: state["artist"] as? String ?? "",
            album: state["album"] as? String ?? ""
        )
        if track != newTrack {
            // Players often report "nothing playing" for a moment between tracks, so compare
            // against the last track seen recently rather than only the current one.
            let recent = lastTrack.flatMap { Date().timeIntervalSince($0.seenAt) < 5 ? $0.track : nil }
            track = newTrack
            if let recent, recent != newTrack { onTrackChange?() }
        }
        lastTrack = (newTrack, Date())

        let playing = state["playing"] as? Bool ?? false
        if playing != isPlaying {
            isPlaying = playing
            pausedAt = playing ? nil : .now
            onPlaybackChange?(playing)
        }
        duration = state["duration"] as? Double ?? 0
        // Some players report a zero rate while playing; assume normal speed then.
        let rate = state["rate"] as? Double ?? 1
        playbackRate = rate > 0 ? rate : 1
        elapsedAnchor = state["elapsed"] as? Double ?? 0
        if let timestamp = state["timestamp"] as? Double {
            anchorDate = Date(timeIntervalSince1970: timestamp)
        } else {
            anchorDate = .now
        }

        if let encoded = state["artwork"] {
            if let base64 = encoded as? String, let data = Data(base64Encoded: base64), let image = NSImage(data: data) {
                artwork = image
                accentColor = image.dominantAccentColor() ?? .white
            } else {
                artwork = nil
                accentColor = .white
            }
        }

        let bundleID = resolveSourceBundleID(
            bundleID: state["bundleId"] as? String,
            parentBundleID: state["parentBundleId"] as? String,
            pid: (state["pid"] as? NSNumber)?.int32Value
        )
        if bundleID != sourceBundleID {
            sourceBundleID = bundleID
            sourceIcon = bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }
    }

    #if DEBUG
    /// Feeds a synthetic track through the normal parsing path, for UI work without playback.
    func debugInject(playing: Bool = true, title: String = "Supernatural", artist: String = "NewJeans") {
        let size = NSSize(width: 300, height: 300)
        let image = NSImage(size: size, flipped: false) { rect in
            NSGradient(colors: [NSColor.systemPink, NSColor.systemPurple, NSColor.systemIndigo])?.draw(in: rect, angle: 45)
            return true
        }
        let tiff = image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?.representation(using: .png, properties: [:])
        var state: [String: Any] = [
            "type": "state", "title": title, "artist": artist, "album": "Single",
            "playing": playing, "duration": 191.0, "elapsed": 42.0, "rate": 1.0,
            "timestamp": Date().timeIntervalSince1970, "bundleId": "com.apple.Music",
        ]
        if let tiff { state["artwork"] = tiff.base64EncodedString() }
        apply(state)
    }
    #endif

    private func clear() {
        track = nil
        isPlaying = false
        duration = 0
        artwork = nil
        accentColor = .white
        sourceBundleID = nil
        sourceIcon = nil
        pausedAt = nil
    }

    /// Browsers and web views report helper processes; walk back to the app the user sees.
    private func resolveSourceBundleID(bundleID: String?, parentBundleID: String?, pid: Int32?) -> String? {
        if let parentBundleID, !parentBundleID.isEmpty { return parentBundleID }
        if let bundleID, !bundleID.hasPrefix("com.apple.WebKit"), !bundleID.isEmpty { return bundleID }
        guard let pid, pid > 0 else { return bundleID }
        let responsible = ResponsibleProcess.pid(for: pid)
        return NSRunningApplication(processIdentifier: responsible)?.bundleIdentifier ?? bundleID
    }
}

/// Wraps the private `responsibility_get_pid_responsible_for_pid`, which maps XPC helpers
/// (e.g. WebKit's GPU process) to the app that launched them.
nonisolated enum ResponsibleProcess {
    private typealias Function = @convention(c) (pid_t) -> pid_t

    private static let function: Function? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else {
            return nil
        }
        return unsafeBitCast(symbol, to: Function.self)
    }()

    static func pid(for pid: pid_t) -> pid_t {
        guard let function else { return pid }
        let responsible = function(pid)
        return responsible > 0 ? responsible : pid
    }
}
