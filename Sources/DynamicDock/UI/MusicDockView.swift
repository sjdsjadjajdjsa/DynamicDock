import SwiftUI

/// Root view of the dock: artwork, scrolling title and artist, visualizer
/// and transport controls on a glass pill.
struct MusicDockView: View {
    let visibility: DockVisibility
    let media: MediaController

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = visibility.isShown
        let title = media.track?.title ?? "Not Playing"

        HStack(spacing: 12) {
            ArtworkView(image: media.artwork)

            VStack(alignment: .leading, spacing: 2) {
                MarqueeText(text: title, font: DesignTokens.titleFont, isActive: shown, restartAt: visibility.shownAt)
                    .foregroundStyle(.primary)
                    .id("title-\(title)")
                MarqueeText(text: subtitle, font: DesignTokens.subtitleFont, isActive: shown, restartAt: visibility.shownAt)
                    .foregroundStyle(.secondary)
                    .id("subtitle-\(subtitle)")
            }

            if media.track != nil {
                VisualizerView(isPlaying: media.isPlaying, isActive: shown)
            }

            TransportControls(media: media)
        }
        .padding(.leading, DesignTokens.artworkInset)
        .padding(.trailing, 14)
        .frame(width: DesignTokens.pillSize.width, height: DesignTokens.pillSize.height)
        .background(GlassBackground())
        // Reduce Motion replaces the slide with a plain fade.
        .scaleEffect(shown || reduceMotion ? 1 : DesignTokens.hiddenScale, anchor: .bottom)
        .offset(y: shown || reduceMotion ? 0 : DesignTokens.hiddenOffset)
        .opacity(shown ? 1 : 0)
        .animation(animation(shown: shown), value: shown)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitle: String {
        if let track = media.track {
            return track.artist.isEmpty ? track.album : track.artist
        }
        return "Open Spotify or Music to begin"
    }

    private func animation(shown: Bool) -> Animation {
        if reduceMotion { return DesignTokens.reducedMotionFade }
        return shown ? DesignTokens.showSpring : DesignTokens.hideSpring
    }
}
