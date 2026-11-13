import AppKit

enum PlaybackState: Sendable {
    case playing, paused, stopped

    /// Parses both the notification form ("Playing") and the AppleScript form ("playing").
    init(_ text: String?) {
        let value = text?.lowercased() ?? ""
        if value.contains("paus") {
            self = .paused
        } else if value.contains("play") || value.contains("forward") || value.contains("rewind") {
            self = .playing
        } else {
            self = .stopped
        }
    }
}

struct TrackInfo: Equatable, Sendable {
    /// Stable identity for change detection and artwork caching.
    let id: String
    let title: String
    let artist: String
    let album: String
}

enum MediaCommand: Sendable {
    case playPause, next, previous
}

/// The players the dock can read from and control, with everything that
/// differs between them.
enum MediaPlayer: CaseIterable, Sendable {
    case spotify, music

    var bundleID: String {
        switch self {
        case .spotify: "com.spotify.client"
        case .music: "com.apple.Music"
        }
    }

    var displayName: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    /// Distributed notification the player posts whenever playback changes.
    var notificationName: Notification.Name {
        switch self {
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        case .music: Notification.Name("com.apple.Music.playerInfo")
        }
    }

    /// Sending an Apple Event to a player that is not running would launch
    /// it, so every send is guarded by this.
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    static func withBundleID(_ bundleID: String?) -> MediaPlayer? {
        allCases.first { $0.bundleID == bundleID }
    }

    /// Builds the track identity the same way from notifications and scripts.
    func track(id: String?, title: String?, artist: String?, album: String?) -> TrackInfo? {
        guard let title, !title.isEmpty else { return nil }
        let artist = artist ?? ""
        let album = album ?? ""
        let identity: String
        switch self {
        case .spotify: identity = id.flatMap { $0.isEmpty ? nil : $0 } ?? "\(title)|\(artist)|\(album)"
        // Music reports different IDs in notifications and scripts, so use the metadata.
        case .music: identity = "\(title)|\(artist)|\(album)"
        }
        return TrackInfo(id: "\(bundleID)#\(identity)", title: title, artist: artist, album: album)
    }

    // MARK: Scripts

    /// A short timeout keeps a hung player from blocking the script thread.
    private func tell(_ body: String) -> String {
        """
        with timeout of 3 seconds
            tell application id "\(bundleID)"
                \(body)
            end tell
        end timeout
        """
    }

    func script(for command: MediaCommand) -> String {
        switch command {
        case .playPause: tell("playpause")
        case .next: tell("next track")
        case .previous: tell("previous track")
        }
    }

    /// Returns {state} or {state, id, title, artist, album}.
    var stateScript: String {
        let id = self == .spotify ? "id of t" : "\"\""
        return tell("""
        if player state is stopped then return {"stopped"}
                set s to player state as text
                try
                    set t to current track
                    return {s, \(id), name of t, artist of t, album of t}
                end try
                return {s}
        """)
    }

    /// Spotify returns an image URL; Music returns the image bytes.
    var artworkScript: String {
        switch self {
        case .spotify:
            tell("""
            try
                        return artwork url of current track
                    end try
                    return ""
            """)
        case .music:
            tell("""
            try
                        return raw data of artwork 1 of current track
                    end try
                    return ""
            """)
        }
    }
}
