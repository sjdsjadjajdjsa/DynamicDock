import AppKit
import SwiftUI

/// One line of text that scrolls when it is too long to fit: it rests,
/// scrolls a full loop at a steady speed, then rests again.
///
/// Give it an `.id` tied to the text so the cycle restarts for new text.
struct MarqueeText: View {
    let text: String
    let font: NSFont
    /// Scrolling runs only while the dock is on screen.
    let isActive: Bool
    /// When the dock was last revealed; the cycle restarts from its rest then.
    let restartAt: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // `@State` is a macro in this SDK and its plugin ships only with Xcode,
    // not the Command Line Tools, so the State storage is declared directly.
    private let createdAt = State(initialValue: Date())

    private var textWidth: CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private var lineHeight: CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    private var label: some View {
        Text(text)
            .font(Font(font as CTFont))
            .lineLimit(1)
    }

    var body: some View {
        GeometryReader { proxy in
            let available = proxy.size.width
            if textWidth <= available || reduceMotion || DesignPreview.isSnapshot {
                label
                    .frame(width: available, alignment: .leading)
            } else {
                // Capped at 60fps: plenty for slow text, and it keeps the work
                // bounded on very high refresh-rate displays.
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
                    let offset = offset(at: context.date)
                    HStack(spacing: DesignTokens.marqueeGap) {
                        label.fixedSize()
                        label.fixedSize()
                    }
                    .offset(x: -offset)
                    .frame(width: available, alignment: .leading)
                    .mask(fadeMask(offset: offset))
                }
            }
        }
        .frame(height: lineHeight)
    }

    /// Distance of one full loop: the text plus the gap before its repeat.
    private var loopDistance: CGFloat { textWidth + DesignTokens.marqueeGap }

    private func offset(at date: Date) -> CGFloat {
        let start = max(createdAt.wrappedValue, restartAt)
        let elapsed = max(date.timeIntervalSince(start), 0)
        let scrollDuration = loopDistance / DesignTokens.marqueeSpeed
        let cycle = DesignTokens.marqueePause + scrollDuration
        let phase = elapsed.truncatingRemainder(dividingBy: cycle)
        guard phase > DesignTokens.marqueePause else { return 0 }
        return (phase - DesignTokens.marqueePause) * DesignTokens.marqueeSpeed
    }

    /// Fades the trailing edge always, and the leading edge only while text
    /// is actually passing through it, so resting text starts crisp.
    private func fadeMask(offset: CGFloat) -> some View {
        let fade = DesignTokens.marqueeFade
        let leadingAmount = min(min(offset, loopDistance - offset) / fade, 1)
        return HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(1 - leadingAmount), .black],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fade)
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: fade)
        }
    }
}
