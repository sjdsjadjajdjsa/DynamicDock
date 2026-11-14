import AppKit
import SwiftUI

/// Large glass card opened by clicking the dock's artwork: album art, track
/// details and controls on the left, an audio visualizer and lyrics on the right. It
/// stops short of the screen edges, and a click in that gap closes it.
struct NowPlayingView: View {
    let media: MediaController
    let spectrum: AudioSpectrum
    let lyrics: LyricsController
    let onClose: () -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: 44, style: .continuous)

    var body: some View {
        GeometryReader { proxy in
            // The card leaves a gap on every side, so the desktop stays visible around it.
            let card = CGSize(
                width: proxy.size.width - max(proxy.size.width * 0.07, 60) * 2,
                height: proxy.size.height - max(proxy.size.height * 0.09, 50) * 2
            )
            let artworkSide = min(card.width * 0.34, card.height * 0.56)
            let image = media.largeArtwork

            ZStack {
                // The gap: a light dim that closes the view when clicked.
                gap
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onClose)

                ZStack {
                    HStack(alignment: .top, spacing: card.width * 0.06) {
                        details(image: image, side: artworkSide)

                        rightColumn(width: card.width * 0.40, side: artworkSide)
                    }

                    closeButton
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(22)
                }
                .frame(width: card.width, height: card.height)
                .background(cardBackground(image: image))
                // Clicks on the card itself do nothing; only the gap closes the view.
                .contentShape(Self.cardShape)
                .onTapGesture {}
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .focusEffectDisabled()
    }

    /// Height of the title, artist and controls under the artwork.
    private static let detailsHeight: CGFloat = 171

    /// The visualizer, with the lyrics under it when the song has any. The
    /// column is as tall as the artwork column beside it.
    private func rightColumn(width: CGFloat, side: CGFloat) -> some View {
        let song = lyrics.lyrics
        let total = side + Self.detailsHeight
        let barsHeight = song == nil ? side : side * 0.42
        let style = DesignPreview.visualizerStyle ?? AppSettings.shared.visualizerStyle

        return VStack(spacing: 0) {
            SpectrumBarsView(spectrum: spectrum, isPlaying: media.isPlaying, style: style)
                // Each style is its own view, so a change crossfades.
                .id(style)
                .transition(.opacity)
                .padding(.horizontal, side * 0.09)
                .padding(.vertical, barsHeight * 0.14)
                .frame(width: width, height: barsHeight)
                .background(panel)
                // Clicking the visualizer moves to the next style. Nothing
                // on screen hints at it, by design.
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        AppSettings.shared.visualizerStyle = style.next
                    }
                }
                .accessibilityHidden(true)

            if let song {
                LyricsView(lyrics: song, currentIndex: lyrics.currentIndex)
                    .padding(.horizontal, 10)
                    .frame(width: width, height: total - barsHeight - 18)
                    .padding(.top, 18)
                    .transition(.opacity)
                    // A new song starts from its own first line.
                    .id(song)
            }
        }
        .frame(width: width, height: total, alignment: .top)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: song != nil)
    }

    private func details(image: NSImage?, side: CGFloat) -> some View {
        VStack(spacing: 0) {
            ArtworkView(image: image, size: side, cornerRadius: side * 0.07)
                .shadow(color: .black.opacity(0.45), radius: 40, y: 18)

            Text(media.track?.title ?? "Not Playing")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.top, 30)

            Text(subtitle)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.top, 6)

            TransportControls(media: media)
                .scaleEffect(1.5)
                .frame(height: 54)
                .padding(.top, 22)
        }
        .frame(width: side)
    }

    private var subtitle: String {
        if let track = media.track {
            return track.artist.isEmpty ? track.album : track.artist
        }
        return "Open Spotify or Music to begin"
    }

    @ViewBuilder
    private var gap: some View {
        if DesignPreview.isSnapshot {
            LinearGradient(
                colors: [
                    Color(red: 0.33, green: 0.40, blue: 0.93),
                    Color(red: 0.80, green: 0.44, blue: 0.76),
                    Color(red: 1.00, green: 0.70, blue: 0.52),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(Color.black.opacity(0.18))
        } else {
            Color.black.opacity(0.18)
        }
    }

    /// The card's surface: glass tinted by the album's colours, with a soft
    /// shadow and a hairline edge.
    private func cardBackground(image: NSImage?) -> some View {
        let shape = Self.cardShape
        return ZStack {
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(0.35), radius: 40, y: 16)
                .mask {
                    Rectangle()
                        .padding(-120)
                        .overlay { shape.blendMode(.destinationOut) }
                        .compositingGroup()
                }

            cardSurface

            if let image {
                // An overlay, so the oversized image cannot stretch the layout.
                Color.clear
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 90)
                    }
                    .clipShape(shape)
                    .opacity(0.30)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            }
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
        .animation(.easeInOut(duration: 0.6), value: image)
    }

    @ViewBuilder
    private var cardSurface: some View {
        let shape = Self.cardShape
        if DesignPreview.isSnapshot {
            shape.fill(Color(red: 0.16, green: 0.14, blue: 0.24).opacity(0.92))
        } else if #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.35)), in: shape)
        } else {
            BackdropBlur()
                .clipShape(shape)
                .overlay(shape.fill(Color.black.opacity(0.30)))
        }
    }

    /// Soft panel behind the visualizer.
    private var panel: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        return shape.fill(Color.white.opacity(0.07))
            .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.16)))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .focusable(false)
        .help("Close (Esc)")
    }
}

/// Blurs whatever is behind the card, where Liquid Glass is unavailable.
private struct BackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
