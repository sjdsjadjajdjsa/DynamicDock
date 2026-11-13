import AppKit
import ImageIO

/// Fetches album artwork for a track, downsampled and cached by track ID.
@MainActor
final class ArtworkLoader {
    enum Outcome {
        case image(NSImage)
        case unavailable
        case permissionDenied
    }

    private let runner = AppleScriptRunner.shared
    private let cache = NSCache<NSString, NSImage>()
    /// Original image data of recent tracks, for the full-screen view.
    private let originals = NSCache<NSString, NSData>()
    private let largeCache = NSCache<NSString, NSImage>()
    private static let largePixelSize = 1600
    /// The thumbnail is drawn at 44pt; this covers 3x displays with headroom.
    private static let maxPixelSize = 192

    init() {
        cache.countLimit = 50
        originals.countLimit = 8
        largeCache.countLimit = 3
    }

    func artwork(for track: TrackInfo, player: MediaPlayer) async -> Outcome {
        if let cached = cache.object(forKey: track.id as NSString) {
            return .image(cached)
        }
        guard player.isRunning else { return .unavailable }

        let output: ScriptOutput
        switch await runner.run(player.artworkScript) {
        case .success(let value): output = value
        case .failure(let error): return error.isPermissionDenied ? .permissionDenied : .unavailable
        }

        let data: Data?
        switch player {
        case .spotify:
            data = await Self.download(output.strings.first)
        case .music:
            data = output.data
        }

        guard let data, let image = Self.thumbnail(from: data, maxPixelSize: Self.maxPixelSize) else {
            return .unavailable
        }
        cache.setObject(image, forKey: track.id as NSString)
        originals.setObject(data as NSData, forKey: track.id as NSString)
        return .image(image)
    }

    /// A sharp, large version of a recent track's artwork, decoded on demand.
    func largeArtwork(forTrackID id: String) -> NSImage? {
        if let cached = largeCache.object(forKey: id as NSString) { return cached }
        guard let data = originals.object(forKey: id as NSString),
              let image = Self.thumbnail(from: data as Data, maxPixelSize: Self.largePixelSize)
        else { return nil }
        largeCache.setObject(image, forKey: id as NSString)
        return image
    }

    private nonisolated static func download(_ urlString: String?) async -> Data? {
        guard let urlString, let url = URL(string: urlString), url.scheme == "https" else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    private static func thumbnail(from data: Data, maxPixelSize: Int) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
