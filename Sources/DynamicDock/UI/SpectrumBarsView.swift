import SwiftUI

/// The looks the now-playing visualizer can take. Clicking it moves to the next.
enum VisualizerStyle: String, CaseIterable {
    case bars, wave, mirror, dots, ring

    var next: VisualizerStyle {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// The visualizer of the now-playing view. It follows the real audio when
/// the system tap delivers it, and falls back to simulated motion when it
/// does not (no permission, or an older macOS).
struct SpectrumBarsView: View {
    let spectrum: AudioSpectrum
    let isPlaying: Bool
    var style: VisualizerStyle = .bars

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // `@State` is a macro whose plugin ships only with Xcode, so the State
    // storage is declared directly (see ControlButton).
    private let smoother = State(initialValue: BarSmoother())

    var body: some View {
        if DesignPreview.isSnapshot {
            let style = style
            Canvas { context, size in
                Self.draw(BarSmoother.simulated(at: 2.4), style: style, in: &context, size: size)
            }
        } else {
            let smoother = smoother.wrappedValue
            let spectrum = spectrum
            let isPlaying = isPlaying
            let style = style
            // Reduce Motion slows the visualizer to a gentle update rather than removing it.
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    let heights = smoother.advance(to: timeline.date, spectrum: spectrum, isPlaying: isPlaying)
                    Self.draw(heights, style: style, in: &context, size: size)
                }
            }
        }
    }

    // MARK: Drawing

    private static func draw(_ heights: [Float], style: VisualizerStyle,
                             in context: inout GraphicsContext, size: CGSize) {
        switch style {
        case .bars: drawBars(heights, mirrored: false, in: &context, size: size)
        case .mirror: drawBars(heights, mirrored: true, in: &context, size: size)
        case .wave: drawWave(heights, in: &context, size: size)
        case .dots: drawDots(heights, in: &context, size: size)
        case .ring: drawRing(heights, in: &context, size: size)
        }
    }

    private static func verticalShading(_ size: CGSize) -> GraphicsContext.Shading {
        .linearGradient(
            Gradient(colors: [.white.opacity(0.95), .white.opacity(0.45)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )
    }

    /// Width of one bar or dot when `count` of them span the view with gaps
    /// half as wide as themselves.
    private static func unitWidth(_ count: Int, in size: CGSize) -> CGFloat {
        size.width / (CGFloat(count) * 1.5 - 0.5)
    }

    /// Bars rising from the bottom, or growing both ways from the centre line.
    private static func drawBars(_ heights: [Float], mirrored: Bool,
                                 in context: inout GraphicsContext, size: CGSize) {
        let barWidth = unitWidth(heights.count, in: size)
        let shading: GraphicsContext.Shading = mirrored ? .color(.white.opacity(0.85)) : verticalShading(size)
        for (index, value) in heights.enumerated() {
            let height = max(CGFloat(value) * size.height, barWidth)
            let rect = CGRect(
                x: CGFloat(index) * barWidth * 1.5,
                y: mirrored ? (size.height - height) / 2 : size.height - height,
                width: barWidth,
                height: height
            )
            context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2, style: .continuous), with: shading)
        }
    }

    /// One smooth line through the levels, softly filled underneath.
    private static func drawWave(_ heights: [Float], in context: inout GraphicsContext, size: CGSize) {
        guard heights.count > 1 else { return }
        let lineWidth: CGFloat = 2.5
        let step = size.width / CGFloat(heights.count - 1)
        let points = heights.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) * step,
                y: size.height - lineWidth - CGFloat(value) * (size.height - lineWidth * 2)
            )
        }

        // Curves through the midpoints between levels, so there are no corners.
        var line = Path()
        line.move(to: points[0])
        for index in 1..<points.count {
            let middle = CGPoint(
                x: (points[index - 1].x + points[index].x) / 2,
                y: (points[index - 1].y + points[index].y) / 2
            )
            line.addQuadCurve(to: middle, control: points[index - 1])
        }
        line.addLine(to: points[points.count - 1])

        var fill = line
        fill.addLine(to: CGPoint(x: size.width, y: size.height))
        fill.addLine(to: CGPoint(x: 0, y: size.height))
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.32), .white.opacity(0.02)]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        ))
        context.stroke(line, with: .color(.white.opacity(0.95)),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    /// A grid of dots; each column lights from the bottom up to its level.
    private static func drawDots(_ heights: [Float], in context: inout GraphicsContext, size: CGSize) {
        let dot = unitWidth(heights.count, in: size)
        let step = dot * 1.5
        let rows = max(Int((size.height + dot * 0.5) / step), 1)
        // Centre the grid vertically in whatever height is left over.
        let top = (size.height - (CGFloat(rows) * step - dot * 0.5)) / 2
        for (column, value) in heights.enumerated() {
            let lit = Int((CGFloat(value) * CGFloat(rows)).rounded())
            for row in 0..<rows {
                let rect = CGRect(
                    x: CGFloat(column) * step,
                    y: top + CGFloat(rows - 1 - row) * step,
                    width: dot,
                    height: dot
                )
                let opacity = row < lit ? 0.95 - 0.5 * Double(row) / Double(rows) : 0.09
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
        }
    }

    /// Bars around a circle, pushing outward. The spectrum runs from the top
    /// down both sides, so the ring is symmetrical.
    private static func drawRing(_ heights: [Float], in context: inout GraphicsContext, size: CGSize) {
        let count = heights.count
        let reach = min(size.width, size.height) / 2
        let inner = reach * 0.42
        let longest = reach - inner
        let lineWidth = max(2 * .pi * inner / CGFloat(count) * 0.55, 1.5)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        for index in 0..<count {
            let half = count / 2
            let band = index < half ? index : count - 1 - index
            let value = CGFloat(heights[min(band * 2, count - 1)])
            let length = max(value * (longest - lineWidth), 0.5)
            let angle = (CGFloat(index) + 0.5) / CGFloat(count) * 2 * .pi - .pi / 2
            let direction = CGPoint(x: cos(angle), y: sin(angle))

            var bar = Path()
            bar.move(to: CGPoint(x: centre.x + direction.x * inner, y: centre.y + direction.y * inner))
            bar.addLine(to: CGPoint(x: centre.x + direction.x * (inner + length),
                                    y: centre.y + direction.y * (inner + length)))
            context.stroke(bar, with: .color(.white.opacity(0.88)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
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
