import AppKit
import SwiftUI

/// Single source of truth for sizes, spacing, timings and springs.
enum DesignTokens {
    // MARK: Pill
    static let pillSize = CGSize(width: 400, height: 64)
    static let cornerRadius: CGFloat = 24
    /// Gap between the pill and the screen edge (or the top of a visible Dock).
    static let bottomMargin: CGFloat = 12

    // MARK: Artwork
    static let artworkSize: CGFloat = 44
    /// Equal inset on the leading, top and bottom sides of the artwork.
    static var artworkInset: CGFloat { (pillSize.height - artworkSize) / 2 }
    /// Concentric with the pill: outer radius minus the inset.
    static var artworkCornerRadius: CGFloat { cornerRadius - artworkInset }

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
    static var panelSize: CGSize {
        CGSize(
            width: pillSize.width + shadowPadding * 2,
            height: pillSize.height + shadowPadding * 2
        )
    }

    // MARK: Edge trigger
    /// Height of the strip at the bottom of the screen that reveals the dock.
    static let triggerThickness: CGFloat = 4
    /// How far the trigger strip extends past each side of the pill.
    static let triggerSideMargin: CGFloat = 80
    /// Default time the cursor must rest on the edge before the dock shows (seconds).
    static let defaultRevealDelay: TimeInterval = 0.1
    /// Minimum dwell when another display sits below, where the edge is not a hard stop.
    static let stackedDisplayDwell: TimeInterval = 0.3
    /// Strip left free at each end of a full-width trigger, clear of hot corners.
    static let triggerCornerInset: CGFloat = 40
    /// Slack around the pill that still counts as "over the dock".
    static let keepAlivePadding: CGFloat = 12
    /// Default time the cursor may stay outside before the dock hides (seconds).
    static let defaultHideDelay: TimeInterval = 0.35
    /// Time allowed for the hide animation before the window is ordered out.
    static let orderOutDelay: Duration = .milliseconds(500)

    // MARK: Motion
    static let showSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let hideSpring = Animation.spring(response: 0.3, dampingFraction: 1.0)
    static let reducedMotionFade = Animation.easeInOut(duration: 0.2)
    static let hiddenScale: CGFloat = 0.96
    /// Distance the pill travels down to be fully off screen, shadow included.
    static var hiddenOffset: CGFloat {
        bottomMargin + pillSize.height + shadowPadding
    }
}
