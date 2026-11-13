import SwiftUI

/// Cava-style bars for the full-screen view. They follow the real audio
/// when the system tap delivers it, and fall back to simulated motion when
/// it does not (no permission, or an older macOS).
struct SpectrumBarsView: View {
    let spectrum: AudioSpectrum
    let isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // `@State` is a macro whose plugin ships only with Xcode, so the State
    // storage is declared directly (see ControlButton).
    private let smoother = State(initialValue: BarSmoother())

    var body: some View {
        if DesignPreview.isSnapshot {
            Canvas { context, size in
                Self.draw(BarSmoother.simulated(at: 2.4), in: &context, size: size)
            }
        } else {
            let smoother = smoother.wrappedValue
            let spectrum = spectrum
            let isPlaying = isPlaying
            // Reduce Motion slows the bars to a gentle update rather than removing them.
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    let heights = smoother.advance(to: timeline.date, spectrum: spectrum, isPlaying: isPlaying)
                    Self.draw(heights, in: &context, size: size)
                }
            }
        }
    }

    private static func draw(_ heights: [Float], in context: inout GraphicsContext, size: CGSize) {
        let count = CGFloat(heights.count)
        // Bars are twice as wide as the gaps between them.
        let barWidth = size.width / (count * 1.5 - 0.5)
        let step = barWidth * 1.5
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white.opacity(0.95), .white.opacity(0.45)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
        for (index, value) in heights.enumerated() {
            let height = max(CGFloat(value) * size.height, barWidth)
            let rect = CGRect(x: CGFloat(index) * step, y: size.height - height, width: barWidth, height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2, style: .continuous), with: shading)
        }
    }
}

/// Bar heights carried from frame to frame, eased so the bars glide rather
/// than jump.
final class BarSmoother: @unchecked Sendable {
    private var heights = [Float](repeating: 0, count: AudioSpectrum.bandCount)
    private var lastDate: Date?
    private let started = Date()

    func advance(to date: Date, spectrum: AudioSpectrum, isPlaying: Bool) -> [Float] {
        let elapsed = Float(min(max(date.timeIntervalSince(lastDate ?? date), 0), 0.1))
        lastDate = date

        let live = spectrum.snapshot()
        let targets: [Float]
        if live.hasSignal {
            targets = live.bands
        } else if isPlaying {
            targets = Self.simulated(at: date.timeIntervalSince(started))
        } else {
            targets = [Float](repeating: 0, count: heights.count)
        }

        // Eased both ways: quicker going up than coming down, never instant.
        let rise = 1 - exp(-elapsed * 11)
        let fall = 1 - exp(-elapsed * 3.5)
        for index in heights.indices {
            let target = targets[index]
            heights[index] += (target - heights[index]) * (target > heights[index] ? rise : fall)
        }
        return heights
    }

    /// Motion that only looks like music, for when no audio is available.
    static func simulated(at time: TimeInterval) -> [Float] {
        let t = Float(time)
        return (0..<AudioSpectrum.bandCount).map { index in
            let x = Float(index)
            let slow = abs(sin(t * 0.6 + x * 0.21))
            let fast = abs(sin(t * 1.5 + x * 0.47))
            let beat = pow(abs(sin(t * 1.6)), 4) * max(0, 1 - x / 14)
            // Lower bars sit higher, like bass-heavy music.
            let tilt = 1 - x / Float(AudioSpectrum.bandCount) * 0.55
            return min((0.12 + 0.5 * slow * fast + 0.45 * beat) * tilt, 1)
        }
    }
}
