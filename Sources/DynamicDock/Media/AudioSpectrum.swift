import Accelerate
import CoreAudio
import Foundation
import QuartzCore

/// Turns a stream of audio samples into bar heights for the full-screen
/// visualizer. Samples arrive on an audio queue; the view reads the latest
/// bands from the main thread.
final class AudioSpectrum: @unchecked Sendable {
    static let bandCount = 48

    private static let fftSize = 2048
    private static let lowestFrequency: Float = 40
    private static let highestFrequency: Float = 16_000

    // Shared between the audio queue and the main thread.
    private let lock = NSLock()
    private var bands = [Float](repeating: 0, count: bandCount)
    private var lastSignal: CFTimeInterval = 0

    // Touched only on the audio queue.
    private let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    private var window = [Float](repeating: 0, count: fftSize)
    private var ring = [Float](repeating: 0, count: fftSize)
    private var writeIndex = 0
    private var bandBins: [(low: Int, high: Int, weight: Float)] = []
    /// Slowly decaying loudest value, so quiet and loud music both fill the bars.
    private var peak: Float = 1
    /// Band levels averaged over the last few buffers, so single-buffer
    /// spikes do not make the bars flicker.
    private var smoothed = [Float](repeating: 0, count: bandCount)

    init() {
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        configure(sampleRate: 48_000)
    }

    deinit {
        if let setup { vDSP_DFT_DestroySetup(setup) }
    }

    /// Lays the bands out on a logarithmic frequency scale. Call before audio starts.
    func configure(sampleRate: Double) {
        let binWidth = Float(sampleRate) / Float(Self.fftSize)
        let lastBin = Self.fftSize / 2 - 1
        let ratio = Self.highestFrequency / Self.lowestFrequency
        var bins: [(low: Int, high: Int, weight: Float)] = []
        var previousHigh = 0
        for index in 0..<Self.bandCount {
            let end = Self.lowestFrequency * pow(ratio, Float(index + 1) / Float(Self.bandCount))
            // Every band gets at least one bin of its own.
            let low = min(previousHigh + 1, lastBin)
            let high = min(max(Int(end / binWidth), low), lastBin)
            let centre = Float(low + high) / 2 * binWidth
            // Music carries less energy higher up; lift it so the bars stay even.
            bins.append((low, high, pow(max(centre, 20) / 100, 0.6)))
            previousHigh = high
        }
        bandBins = bins
    }

    /// The latest bar heights (0...1), and whether real audio arrived recently.
    func snapshot() -> (bands: [Float], hasSignal: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (bands, CACurrentMediaTime() - lastSignal < 1)
    }

    /// Clears the bars, for when listening stops.
    func reset() {
        lock.lock()
        bands = [Float](repeating: 0, count: Self.bandCount)
        lastSignal = 0
        lock.unlock()
    }

    /// Feeds one buffer of 32-bit float audio from the system tap.
    func process(_ bufferList: UnsafePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: bufferList))
        guard let first = buffers.first, let data = first.mData, setup != nil else { return }
        let channels = max(Int(first.mNumberChannels), 1)
        let frames = Int(first.mDataByteSize) / MemoryLayout<Float>.size / channels
        guard frames > 0 else { return }
        let samples = data.assumingMemoryBound(to: Float.self)

        var energy: Float = 0
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels { sum += samples[frame * channels + channel] }
            let mono = sum / Float(channels)
            energy += mono * mono
            ring[writeIndex] = mono
            writeIndex = (writeIndex + 1) % Self.fftSize
        }
        let audible = (energy / Float(frames)).squareRoot() > 0.0001

        // Oldest sample first, windowed.
        var real = [Float](repeating: 0, count: Self.fftSize)
        for index in 0..<Self.fftSize {
            real[index] = ring[(writeIndex + index) % Self.fftSize] * window[index]
        }
        let imaginary = [Float](repeating: 0, count: Self.fftSize)
        var outReal = [Float](repeating: 0, count: Self.fftSize)
        var outImaginary = [Float](repeating: 0, count: Self.fftSize)
        vDSP_DFT_Execute(setup!, real, imaginary, &outReal, &outImaginary)

        // Average energy of each band, eased over time.
        for (index, band) in bandBins.enumerated() {
            var power: Float = 0
            for bin in band.low...band.high {
                power += outReal[bin] * outReal[bin] + outImaginary[bin] * outImaginary[bin]
            }
            let level = (power / Float(band.high - band.low + 1)).squareRoot() * band.weight
            smoothed[index] = smoothed[index] * 0.82 + level * 0.18
        }

        // Blend each bar with its neighbours so the shape flows instead of
        // every bar jumping on its own.
        var values = [Float](repeating: 0, count: Self.bandCount)
        var loudest: Float = 0
        for index in values.indices {
            let left = smoothed[max(index - 1, 0)]
            let right = smoothed[min(index + 1, Self.bandCount - 1)]
            values[index] = left * 0.25 + smoothed[index] * 0.5 + right * 0.25
            loudest = max(loudest, values[index])
        }

        peak = max(peak * 0.998, loudest, 0.05)
        for index in values.indices {
            values[index] = min(values[index] / peak, 1)
        }

        lock.lock()
        bands = values
        if audible { lastSignal = CACurrentMediaTime() }
        lock.unlock()
    }
}
