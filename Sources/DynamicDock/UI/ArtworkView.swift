import SwiftUI

/// Album artwork thumbnail, with a music-note placeholder when none is
/// available. Changes crossfade.
struct ArtworkView: View {
    let image: NSImage?

    @Environment(\.displayScale) private var displayScale

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.artworkCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // A new identity per image makes track changes crossfade.
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            } else {
                ZStack {
                    shape.fill(Color.white.opacity(0.10))
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .frame(width: DesignTokens.artworkSize, height: DesignTokens.artworkSize)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1 / max(displayScale, 1)))
        .shadow(color: .black.opacity(0.28), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.25), value: image)
    }
}
