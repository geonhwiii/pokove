import SwiftUI

/// Album art with a graceful placeholder, plus an optional small badge for the source app.
struct ArtworkView: View {
    var image: NSImage?
    var cornerRadius: CGFloat
    var sourceIcon: NSImage? = nil

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color(white: 0.24), Color(white: 0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            if let sourceIcon {
                Image(nsImage: sourceIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    .offset(x: 6, y: 6)
            }
        }
        .animation(.smooth(duration: 0.3), value: image)
    }
}
