import Foundation

/// Loads the lyrics of the playing track and follows the song's position.
/// It runs only while the now-playing view is open.
@MainActor
@Observable
final class LyricsController {
    private(set) var lyrics: Lyrics?
    /// The line being sung, or -1 before the first line and for unsynced lyrics.
    private(set) var currentIndex = -1

    @ObservationIgnored private let media: MediaController
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Lyrics already looked up, by track ID; nil records "none found".
    @ObservationIgnored private var cache: [String: Lyrics?] = [:]

    @ObservationIgnored private var trackID: String?
    @ObservationIgnored private var wasPlaying = false
    /// The player's reported position and when it was read; the position in
    /// between is worked out from the clock.
    @ObservationIgnored private var anchor: (position: TimeInterval, date: Date)?

    /// How often the view checks which line is current.
    private static let tick: Duration = .milliseconds(100)
    /// Ticks between questions to the player about its position, which also
    /// picks up seeking.
    private static let ticksPerSync = 15
    /// Lines light up slightly early, which reads better than slightly late.
    private static let lead: TimeInterval = 0.2

    init(media: MediaController) {
        self.media = media
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in await self?.run() }
    }

    func stop() {
        task?.cancel()
        task = nil
        trackID = nil
        anchor = nil
        lyrics = nil
        currentIndex = -1
    }

    private func run() async {
        var ticks = 0
        while !Task.isCancelled {
            let track = media.track
            if track?.id != trackID {
                trackID = track?.id
                anchor = nil
                lyrics = nil
                currentIndex = -1
                ticks = 0
            }
            if media.isPlaying != wasPlaying {
                wasPlaying = media.isPlaying
                ticks = 0
            }

            if let track {
                if ticks % Self.ticksPerSync == 0 {
                    await sync(track)
                }
                updateCurrentLine()
            }
            ticks += 1
            try? await Task.sleep(for: Self.tick)
        }
    }

    /// Reads the player's position, and starts the lyrics lookup once the
    /// track's length is known.
    private func sync(_ track: TrackInfo) async {
        guard let playback = await media.playbackPosition(), trackID == track.id else { return }
        anchor = (playback.position, Date())

        if let cached = cache[track.id] {
            if lyrics != cached { lyrics = cached }
        } else {
            // Mark it as looked up so it is not requested again while loading.
            cache[track.id] = .some(nil)
            Task { [weak self] in
                let found = await LyricsService.lyrics(for: track, duration: playback.duration)
                guard let self else { return }
                self.cache[track.id] = .some(found)
                if self.trackID == track.id { self.lyrics = found }
            }
        }
    }

    private func updateCurrentLine() {
        guard let lyrics, lyrics.isSynced, let anchor else {
            if currentIndex != -1 { currentIndex = -1 }
            return
        }
        let elapsed = media.isPlaying ? Date().timeIntervalSince(anchor.date) : 0
        let position = anchor.position + elapsed + Self.lead
        let index = (lyrics.lines.lastIndex { ($0.time ?? 0) <= position }) ?? -1
        if index != currentIndex { currentIndex = index }
    }

    // MARK: Previews

    /// Placeholder lines for design snapshots.
    func loadPreviewData() {
        lyrics = Lyrics(
            lines: [
                "The first line of the song goes here",
                "A second line follows after it",
                "This is the line being sung right now",
                "Then the next line waits its turn",
                "And another one comes after that",
                "Until the verse reaches its end",
            ].enumerated().map { Lyrics.Line(time: Double($0.offset) * 4, text: $0.element) },
            isSynced: true
        )
        currentIndex = 2
    }
}
