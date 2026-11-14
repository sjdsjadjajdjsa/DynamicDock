import Foundation

/// The words of a song, with the time each line starts when known.
struct Lyrics: Hashable, Sendable {
    struct Line: Hashable, Sendable {
        /// Seconds into the song at which the line begins; nil when unsynced.
        let time: TimeInterval?
        let text: String
    }

    let lines: [Line]
    /// True when every line carries a time, so the view can follow the song.
    let isSynced: Bool
}

/// Looks lyrics up on LRCLIB (lrclib.net), a free public lyrics database.
/// The request carries the track's title, artist, album and length.
enum LyricsService {
    private struct Record: Decodable {
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    /// How far a database entry's length may differ from the playing track
    /// before its timing is not trusted.
    private static let durationTolerance = 3.0

    static func lyrics(for track: TrackInfo, duration: TimeInterval) async -> Lyrics? {
        // An exact match first, then a looser search by title and artist.
        if let record = await exactMatch(track, duration: duration), let lyrics = lyrics(from: record, syncedAllowed: true) {
            return lyrics
        }
        var found = await search(title: track.title, artist: track.artist)
        // Players add notes such as "- Remastered 2011" or "(feat. …)" that
        // the database does not have in its titles.
        let plainTitle = simplified(track.title)
        if found.isEmpty, plainTitle != track.title {
            found = await search(title: plainTitle, artist: track.artist)
        }
        let candidates = found
            .filter { $0.instrumental != true }
            .sorted { abs(($0.duration ?? 0) - duration) < abs(($1.duration ?? 0) - duration) }

        let close = candidates.filter { abs(($0.duration ?? 0) - duration) <= durationTolerance }
        if let record = close.first(where: { $0.syncedLyrics?.isEmpty == false }) {
            return lyrics(from: record, syncedAllowed: true)
        }
        // A different length means a different recording: its words are
        // still right, its timing is not.
        if let record = candidates.first(where: { $0.plainLyrics?.isEmpty == false }) {
            return lyrics(from: record, syncedAllowed: false)
        }
        return nil
    }

    private static func exactMatch(_ track: TrackInfo, duration: TimeInterval) async -> Record? {
        await request("get", [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(duration.rounded()))),
        ])
    }

    private static func search(title: String, artist: String) async -> [Record] {
        await request("search", [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]) ?? []
    }

    /// The title without a " - …" suffix or bracketed notes.
    static func simplified(_ title: String) -> String {
        var result = title
        if let dash = result.range(of: " - ") {
            result = String(result[..<dash.lowerBound])
        }
        for (open, close) in [("(", ")"), ("[", "]")] {
            while let start = result.range(of: open),
                  let end = result.range(of: close, range: start.upperBound..<result.endIndex) {
                result.removeSubrange(start.lowerBound..<end.upperBound)
            }
        }
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? title : trimmed
    }

    private static func request<T: Decodable>(_ path: String, _ query: [URLQueryItem]) async -> T? {
        var components = URLComponents(string: "https://lrclib.net/api/\(path)")
        components?.queryItems = query
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func lyrics(from record: Record, syncedAllowed: Bool) -> Lyrics? {
        guard record.instrumental != true else { return nil }
        if syncedAllowed, let synced = record.syncedLyrics {
            let lines = parseSynced(synced)
            if !lines.isEmpty { return Lyrics(lines: lines, isSynced: true) }
        }
        let plain = (record.plainLyrics ?? "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { Lyrics.Line(time: nil, text: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.isEmpty }
        return plain.isEmpty ? nil : Lyrics(lines: plain, isSynced: false)
    }

    /// Parses LRC text: lines of the form `[mm:ss.xx] words`.
    static func parseSynced(_ text: String) -> [Lyrics.Line] {
        var lines: [Lyrics.Line] = []
        for raw in text.split(separator: "\n") {
            var rest = Substring(raw.trimmingCharacters(in: .whitespaces))
            var times: [TimeInterval] = []
            // A line may carry several timestamps when it is sung more than once.
            while rest.hasPrefix("["), let end = rest.firstIndex(of: "]") {
                let stamp = rest[rest.index(after: rest.startIndex)..<end]
                let parts = stamp.split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: end)...]
            }
            let words = rest.trimmingCharacters(in: .whitespaces)
            guard !words.isEmpty else { continue }
            lines += times.map { Lyrics.Line(time: $0, text: words) }
        }
        return lines.sorted { ($0.time ?? 0) < ($1.time ?? 0) }
    }
}
