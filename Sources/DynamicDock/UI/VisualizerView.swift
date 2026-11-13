import AppKit
import QuartzCore
import SwiftUI

/// Five capsule bars that dance while music plays and settle into dots when
/// it pauses. The motion is simulated, not driven by the audio signal.
struct VisualizerView: View {
    let isPlaying: Bool
    /// Animation runs only while the dock is on screen.
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion || DesignPreview.isSnapshot {
                StaticBars(isPlaying: isPlaying)
            } else {
                AnimatedBars(isAnimating: isPlaying && isActive)
            }
        }
        .frame(width: VisualizerMetrics.width, height: DesignTokens.visualizerMaxHeight)
        .accessibilityHidden(true)
    }
}

private enum VisualizerMetrics {
    /// Each bar's height over one loop, as fractions of the maximum height.
    /// Different shapes and durations keep the bars from moving in step.
    static let patterns: [[CGFloat]] = [
        [0.35, 0.80, 0.45, 1.00, 0.30, 0.65],
        [0.70, 0.30, 0.95, 0.50, 0.80, 0.25],
        [0.50, 1.00, 0.35, 0.75, 0.40, 0.90],
        [0.85, 0.40, 0.70, 0.25, 1.00, 0.55],
        [0.30, 0.65, 0.90, 0.40, 0.75, 0.50],
    ]
    static let durations: [CFTimeInterval] = [1.10, 0.90, 1.30, 1.00, 1.20]

    static var count: Int { patterns.count }
    static var width: CGFloat {
        CGFloat(count) * DesignTokens.visualizerBarWidth
            + CGFloat(count - 1) * DesignTokens.visualizerBarGap
    }

    static func height(_ fraction: CGFloat) -> CGFloat {
        max(DesignTokens.visualizerMaxHeight * fraction, DesignTokens.visualizerMinHeight)
    }
}

/// Motionless version for Reduce Motion and design snapshots.
private struct StaticBars: View {
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: DesignTokens.visualizerBarGap) {
            ForEach(0..<VisualizerMetrics.count, id: \.self) { index in
                Capsule()
                    .fill(Color.primary.opacity(0.9))
                    .frame(
                        width: DesignTokens.visualizerBarWidth,
                        height: isPlaying
                            ? VisualizerMetrics.height(VisualizerMetrics.patterns[index][1])
                            : DesignTokens.visualizerMinHeight
                    )
            }
        }
    }
}

private struct AnimatedBars: NSViewRepresentable {
    let isAnimating: Bool

    func makeNSView(context: Context) -> VisualizerLayerView {
        VisualizerLayerView()
    }

    func updateNSView(_ nsView: VisualizerLayerView, context: Context) {
        nsView.setAnimating(isAnimating)
    }
}

/// Core Animation bars. The animations run in the render server at the
/// display's refresh rate, so this process does no per-frame work.
final class VisualizerLayerView: NSView {
    private static let heightKeyPath = "bounds.size.height"
    private static let introDuration: CFTimeInterval = 0.18

    private var bars: [CALayer] = []
    private var isAnimating = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        for _ in 0..<VisualizerMetrics.count {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            bar.cornerRadius = DesignTokens.visualizerBarWidth / 2
            bar.cornerCurve = .continuous
            bar.bounds = CGRect(
                x: 0, y: 0,
                width: DesignTokens.visualizerBarWidth,
                height: DesignTokens.visualizerMinHeight
            )
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let step = DesignTokens.visualizerBarWidth + DesignTokens.visualizerBarGap
        for (index, bar) in bars.enumerated() {
            // Bars are anchored at their centre, so they grow up and down equally.
            bar.position = CGPoint(
                x: CGFloat(index) * step + DesignTokens.visualizerBarWidth / 2,
                y: bounds.midY
            )
        }
        CATransaction.commit()
    }

    func setAnimating(_ animating: Bool) {
        guard animating != isAnimating else { return }
        isAnimating = animating
        for (index, bar) in bars.enumerated() {
            if animating {
                start(bar, index: index)
            } else {
                settle(bar)
            }
        }
    }

    private func currentHeight(of bar: CALayer) -> CGFloat {
        bar.presentation()?.bounds.height ?? bar.bounds.height
    }

    private func setModelHeight(_ height: CGFloat, on bar: CALayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bar.bounds.size.height = height
        CATransaction.commit()
    }

    /// Eases from wherever the bar is into its loop, then loops forever.
    private func start(_ bar: CALayer, index: Int) {
        let from = currentHeight(of: bar)
        let heights = VisualizerMetrics.patterns[index].map(VisualizerMetrics.height)
        bar.removeAllAnimations()
        setModelHeight(heights[0], on: bar)

        let intro = CABasicAnimation(keyPath: Self.heightKeyPath)
        intro.fromValue = from
        intro.toValue = heights[0]
        intro.duration = Self.introDuration
        intro.timingFunction = CAMediaTimingFunction(name: .easeOut)
        bar.add(intro, forKey: "intro")

        let loop = CAKeyframeAnimation(keyPath: Self.heightKeyPath)
        loop.values = heights + [heights[0]]
        loop.calculationMode = .cubic
        loop.duration = VisualizerMetrics.durations[index]
        loop.repeatCount = .infinity
        loop.beginTime = bar.convertTime(CACurrentMediaTime(), from: nil) + Self.introDuration
        bar.add(loop, forKey: "loop")
    }

    /// Springs from wherever the bar is down to a resting dot.
    private func settle(_ bar: CALayer) {
        let from = currentHeight(of: bar)
        bar.removeAllAnimations()
        setModelHeight(DesignTokens.visualizerMinHeight, on: bar)

        let spring = CASpringAnimation(keyPath: Self.heightKeyPath)
        spring.fromValue = from
        spring.toValue = DesignTokens.visualizerMinHeight
        spring.mass = 1
        spring.stiffness = 220
        spring.damping = 18
        spring.duration = spring.settlingDuration
        bar.add(spring, forKey: "settle")
    }
}
