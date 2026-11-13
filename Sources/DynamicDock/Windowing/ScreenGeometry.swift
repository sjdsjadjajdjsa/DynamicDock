import AppKit

/// Pure geometry in AppKit global coordinates (origin bottom-left, y up).
enum ScreenGeometry {
    /// The screen whose frame contains `point`, edges included. The cursor can
    /// sit exactly on a frame edge, which `NSMouseInRect` would exclude.
    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { inclusiveContains($0.frame, point) }
    }

    static func inclusiveContains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX
            && point.y >= rect.minY && point.y <= rect.maxY
    }

    /// Strip along the bottom edge that reveals the dock: centred on the pill,
    /// or the whole edge minus the corners when `fullWidth` is set.
    static func triggerRect(screenFrame: CGRect, fullWidth: Bool) -> CGRect {
        let width = fullWidth
            ? screenFrame.width - DesignTokens.triggerCornerInset * 2
            : DesignTokens.pillSize.width + DesignTokens.triggerSideMargin * 2
        return CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.minY,
            width: width,
            height: DesignTokens.triggerThickness
        )
    }

    /// Where the pill rests when shown: centred, `bottomMargin` above the
    /// screen edge, or above the Dock when a visible Dock occupies the bottom.
    static func pillFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let size = DesignTokens.pillSize
        let baseline = max(screenFrame.minY, visibleFrame.minY)
        return CGRect(
            x: (screenFrame.midX - size.width / 2).rounded(),
            y: baseline + DesignTokens.bottomMargin,
            width: size.width,
            height: size.height
        )
    }

    /// Window frame: the pill plus transparent shadow padding on every side.
    static func panelFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        pillFrame(screenFrame: screenFrame, visibleFrame: visibleFrame)
            .insetBy(dx: -DesignTokens.shadowPadding, dy: -DesignTokens.shadowPadding)
    }

    /// Area in which the cursor keeps the dock open: the pill plus padding,
    /// extended down to the screen edge so there is no gap under the pill.
    static func keepAliveRect(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let pill = pillFrame(screenFrame: screenFrame, visibleFrame: visibleFrame)
        let padding = DesignTokens.keepAlivePadding
        return CGRect(
            x: pill.minX - padding,
            y: screenFrame.minY,
            width: pill.width + padding * 2,
            height: pill.maxY + padding - screenFrame.minY
        )
    }

    /// True when another display sits directly below `screenFrame` at the
    /// cursor's x position, so the bottom edge does not stop the cursor.
    static func hasScreenBelow(_ point: CGPoint, screenFrame: CGRect, allFrames: [CGRect]) -> Bool {
        allFrames.contains { other in
            other != screenFrame
                && abs(other.maxY - screenFrame.minY) < 1
                && point.x >= other.minX && point.x <= other.maxX
        }
    }
}
