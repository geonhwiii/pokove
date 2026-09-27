import SwiftUI

/// "QuickPeek": the media activity grows a line to announce the new track.
struct MediaPeekView: View {
    let layout: NotchLayout

    @Environment(AppModel.self) private var app

    var body: some View {
        let media = app.nowPlaying
        let wing = layout.wingWidth(for: .media) + 30
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ArtworkView(image: media.artwork, cornerRadius: 6)
                    .frame(width: layout.notch.height - 10, height: layout.notch.height - 10)
                    .padding(.leading, 10)
                    .frame(width: wing, alignment: .leading)
                Spacer(minLength: layout.notch.width)
                AudioVisualizer(
                    isPlaying: media.isPlaying,
                    color: app.preferences.tintWithArtwork ? Color(nsColor: media.accentColor) : .white
                )
                .frame(width: 18, height: 14)
                .padding(.trailing, 12)
                .frame(width: wing, alignment: .trailing)
            }
            .frame(height: layout.notch.height)

            MarqueeText(text: peekText, symbol: "music.note", font: .system(size: 12, weight: .semibold))
            .padding(.horizontal, 18)
            .frame(height: NotchLayout.peekContentHeight - 6)
        }
    }

    private var peekText: String {
        guard let track = app.nowPlaying.track else { return "" }
        return track.artist.isEmpty ? track.title : "\(track.title) · \(track.artist)"
    }
}
