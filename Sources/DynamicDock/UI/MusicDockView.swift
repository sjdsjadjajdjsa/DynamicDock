import SwiftUI

/// Root view of the dock: artwork, scrolling title and artist, visualizer
/// and transport controls on a glass pill. The pill is wide on the bottom
/// edge and tall on the side edges.
struct MusicDockView: View {
    let visibility: DockVisibility
    let media: MediaController
    /// Fixed layout for design snapshots; the live dock follows the settings.
    var layoutOverride: DockLayout?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = visibility.isShown
        let layout = layoutOverride ?? AppSettings.shared.layout
        let moved = !(shown || reduceMotion)

        Group {
            if layout.edge.isVertical {
                verticalContent(shown: shown)
            } else {
                horizontalContent(shown: shown)
            }
        }
        .frame(width: layout.pillSize.width, height: layout.pillSize.height)
        .background(GlassBackground())
        // Reduce Motion replaces the slide with a plain fade.
        .scaleEffect(moved ? DesignTokens.hiddenScale : 1, anchor: scaleAnchor(for: layout.edge))
        .offset(moved ? layout.hiddenOffset : .zero)
        .opacity(shown ? 1 : 0)
        .animation(animation(shown: shown), value: shown)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func horizontalContent(shown: Bool) -> some View {
        HStack(spacing: 12) {
            ArtworkView(image: media.artwork)

            VStack(alignment: .leading, spacing: 2) {
                textLines(shown: shown, alignment: .leading)
            }

            if media.track != nil {
                VisualizerView(isPlaying: media.isPlaying, isActive: shown)
            }

            TransportControls(media: media)
        }
        .padding(.leading, DesignTokens.artworkInset)
        .padding(.trailing, 14)
    }

    private func verticalContent(shown: Bool) -> some View {
        VStack(spacing: 0) {
            ArtworkView(
                image: media.artwork,
                size: DesignTokens.verticalArtworkSize,
                cornerRadius: DesignTokens.cornerRadius - DesignTokens.verticalArtworkInset
            )

            VStack(spacing: 2) {
                textLines(shown: shown, alignment: .center)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            Spacer(minLength: 0)
            if media.track != nil {
                VisualizerView(isPlaying: media.isPlaying, isActive: shown)
            }
            Spacer(minLength: 0)

            TransportControls(media: media, vertical: true)
        }
        .padding(.top, DesignTokens.verticalArtworkInset)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func textLines(shown: Bool, alignment: Alignment) -> some View {
        let title = media.track?.title ?? "Not Playing"
        MarqueeText(text: title, font: DesignTokens.titleFont, isActive: shown,
                    restartAt: visibility.shownAt, alignment: alignment)
            .foregroundStyle(.primary)
            .id("title-\(title)")
        MarqueeText(text: subtitle, font: DesignTokens.subtitleFont, isActive: shown,
                    restartAt: visibility.shownAt, alignment: alignment)
            .foregroundStyle(.secondary)
            .id("subtitle-\(subtitle)")
    }

    private var subtitle: String {
        if let track = media.track {
            return track.artist.isEmpty ? track.album : track.artist
        }
        return "Open Spotify or Music to begin"
    }

    private func scaleAnchor(for edge: DockEdge) -> UnitPoint {
        switch edge {
        case .bottom: return .bottom
        case .left: return .leading
        case .right: return .trailing
        }
    }

    private func animation(shown: Bool) -> Animation {
        if reduceMotion { return DesignTokens.reducedMotionFade }
        return shown ? DesignTokens.showSpring : DesignTokens.hideSpring
    }
}
