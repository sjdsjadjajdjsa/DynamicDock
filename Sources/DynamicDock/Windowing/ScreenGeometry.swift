import AppKit

/// Screen lookups in AppKit global coordinates (origin bottom-left, y up).
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
}

/// The screen edge the dock lives on.
enum DockEdge: String, CaseIterable {
    case bottom, left, right

    /// Side edges use the tall, vertical pill.
    var isVertical: Bool { self != .bottom }
}

/// Where the dock sits and which part of the edge reveals it. Pure geometry
/// in AppKit global coordinates (origin bottom-left, y up).
struct DockLayout: Equatable {
    var edge: DockEdge = .bottom
    /// Place along the edge, 0...1: left to right on the bottom edge, bottom
    /// to top on the side edges.
    var position: CGFloat = 0.5
    /// Gap between the pill and the screen edge (or a visible Dock there).
    var margin: CGFloat = DesignTokens.defaultEdgeMargin
    /// Whether the whole edge reveals the dock, rather than the part near it.
    var fullEdgeTrigger = false

    var pillSize: CGSize {
        edge.isVertical ? DesignTokens.verticalPillSize : DesignTokens.horizontalPillSize
    }

    /// Window size: the pill plus transparent shadow padding on every side.
    var panelSize: CGSize {
        CGSize(
            width: pillSize.width + DesignTokens.shadowPadding * 2,
            height: pillSize.height + DesignTokens.shadowPadding * 2
        )
    }

    /// How far the pill travels to be fully off screen, shadow included, in
    /// SwiftUI coordinates (y down).
    var hiddenOffset: CGSize {
        let shadow = DesignTokens.shadowPadding
        switch edge {
        case .bottom: return CGSize(width: 0, height: margin + pillSize.height + shadow)
        case .left: return CGSize(width: -(margin + pillSize.width + shadow), height: 0)
        case .right: return CGSize(width: margin + pillSize.width + shadow, height: 0)
        }
    }

    /// Where the pill rests when shown.
    func pillFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let size = pillSize
        let inset = DesignTokens.edgeEndInset
        let x: CGFloat
        let y: CGFloat
        switch edge {
        case .bottom:
            x = Self.place(position, from: visibleFrame.minX + inset, to: visibleFrame.maxX - inset - size.width)
            y = max(screenFrame.minY, visibleFrame.minY) + margin
        case .left:
            x = max(screenFrame.minX, visibleFrame.minX) + margin
            y = Self.place(position, from: visibleFrame.minY + inset, to: visibleFrame.maxY - inset - size.height)
        case .right:
            x = min(screenFrame.maxX, visibleFrame.maxX) - margin - size.width
            y = Self.place(position, from: visibleFrame.minY + inset, to: visibleFrame.maxY - inset - size.height)
        }
        return CGRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }

    private static func place(_ position: CGFloat, from low: CGFloat, to high: CGFloat) -> CGFloat {
        low + (max(high, low) - low) * min(max(position, 0), 1)
    }

    func panelFrame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        pillFrame(screenFrame: screenFrame, visibleFrame: visibleFrame)
            .insetBy(dx: -DesignTokens.shadowPadding, dy: -DesignTokens.shadowPadding)
    }

    /// Strip along the edge that reveals the dock: alongside the pill, or the
    /// whole edge minus the corners when `fullEdgeTrigger` is set.
    func triggerRect(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let pill = pillFrame(screenFrame: screenFrame, visibleFrame: visibleFrame)
        let thickness = DesignTokens.triggerThickness
        let sideMargin = DesignTokens.triggerSideMargin
        let corner = DesignTokens.triggerCornerInset

        switch edge {
        case .bottom:
            let low = fullEdgeTrigger ? screenFrame.minX + corner : max(pill.minX - sideMargin, screenFrame.minX)
            let high = fullEdgeTrigger ? screenFrame.maxX - corner : min(pill.maxX + sideMargin, screenFrame.maxX)
            return CGRect(x: low, y: screenFrame.minY, width: high - low, height: thickness)
        case .left, .right:
            let low = fullEdgeTrigger ? screenFrame.minY + corner : max(pill.minY - sideMargin, screenFrame.minY)
            let high = fullEdgeTrigger ? screenFrame.maxY - corner : min(pill.maxY + sideMargin, screenFrame.maxY)
            let x = edge == .left ? screenFrame.minX : screenFrame.maxX - thickness
            return CGRect(x: x, y: low, width: thickness, height: high - low)
        }
    }

    /// Area in which the cursor keeps the dock open: the pill plus padding,
    /// extended to the screen edge so there is no gap beside the pill.
    func keepAliveRect(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let padded = pillFrame(screenFrame: screenFrame, visibleFrame: visibleFrame)
            .insetBy(dx: -DesignTokens.keepAlivePadding, dy: -DesignTokens.keepAlivePadding)
        switch edge {
        case .bottom:
            return CGRect(x: padded.minX, y: screenFrame.minY,
                          width: padded.width, height: padded.maxY - screenFrame.minY)
        case .left:
            return CGRect(x: screenFrame.minX, y: padded.minY,
                          width: padded.maxX - screenFrame.minX, height: padded.height)
        case .right:
            return CGRect(x: padded.minX, y: padded.minY,
                          width: screenFrame.maxX - padded.minX, height: padded.height)
        }
    }

    /// True when another display continues past the dock's edge at the
    /// cursor's position, so the edge does not stop the cursor.
    func hasScreenBeyondEdge(_ point: CGPoint, screenFrame: CGRect, allFrames: [CGRect]) -> Bool {
        allFrames.contains { other in
            guard other != screenFrame else { return false }
            switch edge {
            case .bottom:
                return abs(other.maxY - screenFrame.minY) < 1 && point.x >= other.minX && point.x <= other.maxX
            case .left:
                return abs(other.maxX - screenFrame.minX) < 1 && point.y >= other.minY && point.y <= other.maxY
            case .right:
                return abs(other.minX - screenFrame.maxX) < 1 && point.y >= other.minY && point.y <= other.maxY
            }
        }
    }
}
