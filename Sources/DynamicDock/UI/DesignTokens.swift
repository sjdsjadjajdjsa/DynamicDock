import AppKit
import SwiftUI

/// Single source of truth for sizes, spacing, timings and springs.
enum DesignTokens {
    // MARK: Pill
    /// The wide pill used on the bottom edge.
    static let horizontalPillSize = CGSize(width: 400, height: 64)
    /// The tall pill used on the left and right edges.
    static let verticalPillSize = CGSize(width: 84, height: 264)
    static let cornerRadius: CGFloat = 24
    /// Default gap between the pill and the screen edge (or a visible Dock).
    static let defaultEdgeMargin: CGFloat = 12
    /// Space kept between the pill and the ends of its edge.
    static let edgeEndInset: CGFloat = 8

    // MARK: Artwork
    static let artworkSize: CGFloat = 44
    static let verticalArtworkSize: CGFloat = 60
    /// Equal inset between the artwork and the three pill sides around it.
    static var artworkInset: CGFloat { (horizontalPillSize.height - artworkSize) / 2 }
    static var verticalArtworkInset: CGFloat { (verticalPillSize.width - verticalArtworkSize) / 2 }

    // MARK: Surface
    /// Dark tint over the glass, for legibility on bright wallpapers.
    static let glassTintOpacity: Double = 0.22

    // MARK: Text
    static var titleFont: NSFont { .systemFont(ofSize: 13, weight: .semibold) }
    static var subtitleFont: NSFont { .systemFont(ofSize: 12, weight: .regular) }
    /// Scroll speed of over-long text, in points per second.
    static let marqueeSpeed: CGFloat = 30
    /// Rest at the start of each scroll loop, in seconds.
    static let marqueePause: TimeInterval = 1.5
    /// Space between the end of the text and its repeat.
    static let marqueeGap: CGFloat = 36
    /// Width of the soft fade at the clipped edges.
    static let marqueeFade: CGFloat = 12

    // MARK: Visualizer
    static let visualizerBarWidth: CGFloat = 3
    static let visualizerBarGap: CGFloat = 3
    static let visualizerMinHeight: CGFloat = 3
    static let visualizerMaxHeight: CGFloat = 18

    // MARK: Shadow
    // Kept tight and nearly centred: the pill sits close to the screen edge,
    // and a deep downward shadow gets cut off there and squares off the
    // bottom corners.
    static let ambientShadowOpacity: Double = 0.22
    static let ambientShadowRadius: CGFloat = 10
    static let ambientShadowOffset: CGFloat = 2

    // MARK: Window
    /// Transparent margin around the pill so its shadow is not clipped.
    static let shadowPadding: CGFloat = 40

    // MARK: Edge trigger
    /// Thickness of the strip along the screen edge that reveals the dock.
    static let triggerThickness: CGFloat = 4
    /// How far the trigger strip extends past each end of the pill.
    static let triggerSideMargin: CGFloat = 80
    /// Default time the cursor must rest on the edge before the dock shows (seconds).
    static let defaultRevealDelay: TimeInterval = 0.1
    /// Minimum dwell when another display continues past the edge, where it is not a hard stop.
    static let stackedDisplayDwell: TimeInterval = 0.3
    /// Strip left free at each end of a full-edge trigger, clear of hot corners.
    static let triggerCornerInset: CGFloat = 40
    /// Slack around the pill that still counts as "over the dock".
    static let keepAlivePadding: CGFloat = 12
    /// Default time the cursor may stay outside before the dock hides (seconds).
    static let defaultHideDelay: TimeInterval = 0.35
    /// Time allowed for the hide animation before the window is ordered out.
    static let orderOutDelay: Duration = .milliseconds(500)
    /// How long the dock stays up after a position setting changes (seconds).
    static let layoutPreviewDuration: TimeInterval = 1.5

    // MARK: Motion
    static let showSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let hideSpring = Animation.spring(response: 0.3, dampingFraction: 1.0)
    static let reducedMotionFade = Animation.easeInOut(duration: 0.2)
    static let hiddenScale: CGFloat = 0.96
}
