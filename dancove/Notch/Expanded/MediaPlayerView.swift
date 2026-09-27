import SwiftUI

/// Alcove-style player: artwork and titles, a thick scrubber, and five controls.
struct MediaPlayerView: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app

    var body: some View {
        let media = app.nowPlaying
        let tint = app.preferences.tintWithArtwork && media.artwork != nil ? Color(nsColor: media.accentColor) : .white

        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                FlippingArtwork(image: media.artwork, trackKey: media.track?.title ?? "")
                    .frame(width: 60, height: 60)
                    .onTapGesture(perform: openSourceApp)
                    .help("Open \(sourceName)")

                VStack(alignment: .leading, spacing: 3) {
                    Text(media.track?.title ?? String(localized: "Nothing Playing"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                if media.hasMedia {
                    AudioVisualizer(isPlaying: media.isPlaying, color: tint)
                        .frame(width: 22, height: 18)
                        .padding(.top, 10)
                }
            }

            ScrubberView(viewModel: viewModel, tint: tint)
                .disabled(!media.hasMedia || media.duration <= 0)

            ControlsRow()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .animation(.smooth(duration: 0.3), value: media.track)
    }

    private var subtitle: String {
        guard let track = app.nowPlaying.track else { return String(localized: "Play something in Music, Spotify or a browser") }
        return [track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " — ")
    }

    private var sourceName: String {
        guard let id = app.nowPlaying.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return String(localized: "app") }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func openSourceApp() {
        guard let id = app.nowPlaying.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        viewModel.close()
    }
}

/// Artwork that flips horizontally when the track changes.
private struct FlippingArtwork: View {
    let image: NSImage?
    let trackKey: String

    @State private var rotation: Double = 0

    var body: some View {
        ArtworkView(image: image, cornerRadius: 12)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .onChange(of: trackKey) {
                rotation = 0
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { rotation = 360 }
            }
    }
}

private struct ScrubberView: View {
    let viewModel: NotchViewModel
    let tint: Color

    @Environment(AppModel.self) private var app
    @State private var dragFraction: Double?
    @State private var isHovering = false

    var body: some View {
        let media = app.nowPlaying
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = max(media.duration, 0)
            let elapsed = dragFraction.map { $0 * duration } ?? media.elapsed(at: context.date)
            let fraction = duration > 0 ? elapsed / duration : 0

            HStack(spacing: 10) {
                Text(duration > 0 ? Self.format(elapsed) : "--:--")
                    .frame(width: 38, alignment: .leading)
                GeometryReader { proxy in
                    let height: CGFloat = isHovering || dragFraction != nil ? 8 : 6
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(height, proxy.size.width * CGFloat(min(max(fraction, 0), 1))))
                            .opacity(duration > 0 ? 1 : 0)
                    }
                    .frame(height: height)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.isInteracting = true
                                dragFraction = min(max(value.location.x / proxy.size.width, 0), 1)
                            }
                            .onEnded { value in
                                let fraction = min(max(value.location.x / proxy.size.width, 0), 1)
                                media.seek(to: fraction * duration)
                                dragFraction = nil
                                viewModel.isInteracting = false
                            }
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: height)
                }
                .frame(height: 14)
                .onHover { isHovering = $0 }
                .onDisappear {
                    // The page can be swapped mid-drag, in which case onEnded never fires.
                    if dragFraction != nil {
                        dragFraction = nil
                        viewModel.isInteracting = false
                    }
                }
                Text(duration > 0 ? "-" + Self.format(max(0, duration - elapsed)) : "--:--")
                    .frame(width: 42, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

private struct ControlsRow: View {
    @Environment(AppModel.self) private var app
    @State private var outputs: [AudioOutputDevices.Device] = []
    @State private var currentOutput: AudioOutputDevices.Device?

    var body: some View {
        let media = app.nowPlaying
        HStack(spacing: 0) {
            Button(action: openSource) {
                Group {
                    if let icon = media.sourceIcon {
                        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .frame(width: 46, height: 38)
                .contentShape(Rectangle())
            }
            .help("Open source app")
            .opacity(media.sourceIcon == nil ? 0.5 : 0.85)

            Spacer()

            ControlButton(symbol: "backward.fill", size: 19) { media.previousTrack() }
            ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 27) { media.togglePlayPause() }
                .padding(.horizontal, 10)
            ControlButton(symbol: "forward.fill", size: 19) { media.nextTrack() }

            Spacer()

            Menu {
                ForEach(outputs) { device in
                    Button {
                        AudioOutputDevices.select(device)
                        currentOutput = device
                    } label: {
                        if device.id == currentOutput?.id {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                Image(systemName: currentOutput?.symbol ?? "hifispeaker")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 46, height: 38)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 10))
            .fixedSize()
            .help("Audio output")
        }
        .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 10))
        .disabled(!media.hasMedia)
        .onAppear(perform: refreshOutputs)
    }

    private func refreshOutputs() {
        outputs = AudioOutputDevices.outputs
        currentOutput = AudioOutputDevices.current
    }

    private func openSource() {
        guard let id = app.nowPlaying.sourceBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    @State private var bounce = 0

    var body: some View {
        Button {
            bounce += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce.down, value: bounce)
                .frame(width: size + 26, height: 38)
                .contentShape(Rectangle())
        }
    }
}
