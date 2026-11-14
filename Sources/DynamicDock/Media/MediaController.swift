import AppKit
import CoreServices

/// Tracks what Spotify and Music are playing and sends them commands.
///
/// Updates are push-based: both players post a distributed notification on
/// every change, so nothing is polled. Apple Events are used only for the
/// initial state, artwork and commands.
@MainActor
@Observable
final class MediaController {
    struct PlayerStatus {
        var state: PlaybackState = .stopped
        var track: TrackInfo?
        var artwork: NSImage?
        /// Automation access was refused, so artwork and commands are unavailable.
        var permissionDenied = false
        /// When this player last started playing; decides which player is shown.
        var lastStartedPlaying = Date.distantPast
    }

    /// Status of each running player.
    private(set) var statuses: [MediaPlayer: PlayerStatus] = [:]

    @ObservationIgnored private let runner = AppleScriptRunner.shared
    @ObservationIgnored private let artworkLoader = ArtworkLoader()
    @ObservationIgnored private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    // MARK: What the dock shows

    /// The player to display: one that is playing wins, most recent first.
    var activePlayer: MediaPlayer? {
        MediaPlayer.allCases
            .compactMap { player in statuses[player].map { (player, $0) } }
            .filter { $0.1.track != nil }
            .max { lhs, rhs in
                let l = (lhs.1.state == .playing ? 1 : 0, lhs.1.lastStartedPlaying)
                let r = (rhs.1.state == .playing ? 1 : 0, rhs.1.lastStartedPlaying)
                return l < r
            }?.0
    }

    private var activeStatus: PlayerStatus? { activePlayer.flatMap { statuses[$0] } }

    var track: TrackInfo? { activeStatus?.track }
    var artwork: NSImage? { activeStatus?.artwork }
    var isPlaying: Bool { activeStatus?.state == .playing }

    /// The artwork at full-screen quality, or the thumbnail when the original
    /// is no longer cached.
    var largeArtwork: NSImage? {
        guard let track, let artwork else { return nil }
        return artworkLoader.largeArtwork(forTrackID: track.id) ?? artwork
    }

    /// The player commands go to: the displayed one, or any running player
    /// when nothing is loaded yet.
    var commandTarget: MediaPlayer? {
        activePlayer ?? MediaPlayer.allCases.first { statuses[$0] != nil }
    }

    /// Set when the player we would control has refused Automation access.
    var playerNeedingPermission: MediaPlayer? {
        guard let target = commandTarget, statuses[target]?.permissionDenied == true else { return nil }
        return target
    }

    // MARK: Lifecycle

    func start() {
        guard observers.isEmpty else { return }

        for player in MediaPlayer.allCases {
            let center = DistributedNotificationCenter.default()
            let token = center.addObserver(forName: player.notificationName, object: nil, queue: .main) { [weak self] note in
                let info = Self.stringValues(note.userInfo)
                MainActor.assumeIsolated { self?.handlePlayerNotification(player, info: info) }
            }
            observers.append((center, token))
        }

        let workspace = NSWorkspace.shared.notificationCenter
        let launched = workspace.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.playerDidLaunch(MediaPlayer.withBundleID(bundleID)) }
        }
        let terminated = workspace.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                if let player = MediaPlayer.withBundleID(bundleID) { self?.statuses[player] = nil }
            }
        }
        observers.append((workspace, launched))
        observers.append((workspace, terminated))

        for player in MediaPlayer.allCases where player.isRunning {
            Task { await refresh(player) }
        }
    }

    private func playerDidLaunch(_ player: MediaPlayer?) {
        guard let player else { return }
        Task {
            // Give the player a moment to finish launching before scripting it.
            try? await Task.sleep(for: .seconds(2))
            await refresh(player)
        }
    }

    // MARK: Commands

    func send(_ command: MediaCommand) {
        guard let player = commandTarget, player.isRunning else { return }
        Task {
            if case .failure(let error) = await runner.run(player.script(for: command)), error.isPermissionDenied {
                statuses[player]?.permissionDenied = true
            }
        }
    }

    /// How far into the track the displayed player is, and the track's
    /// length, both in seconds.
    func playbackPosition() async -> (position: TimeInterval, duration: TimeInterval)? {
        guard let player = activePlayer, player.isRunning,
              case .success(let output) = await runner.run(player.positionScript)
        else { return nil }
        // Numbers may come back with a decimal comma, depending on the region.
        let values = output.strings.compactMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        guard values.count == 2 else { return nil }
        return (values[0], player.seconds(fromDuration: values[1]))
    }

    /// Opens Privacy & Security → Automation, where access can be granted.
    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: State updates

    /// Asks the player for its state directly. Used at launch and whenever
    /// access may have changed.
    private func refresh(_ player: MediaPlayer) async {
        guard player.isRunning else {
            statuses[player] = nil
            return
        }

        let permission = await runner.automationPermission(for: player.bundleID)
        if permission == OSStatus(errAEEventNotPermitted) {
            statuses[player, default: PlayerStatus()].permissionDenied = true
            return
        }
        guard permission == noErr else { return }
        statuses[player, default: PlayerStatus()].permissionDenied = false

        switch await runner.run(player.stateScript) {
        case .success(let output):
            let fields = output.strings
            let state = PlaybackState(fields.first)
            let track = fields.count >= 5
                ? player.track(id: fields[1], title: fields[2], artist: fields[3], album: fields[4])
                : nil
            apply(player, state: state, track: state == .stopped ? nil : track)
        case .failure(let error):
            if error.isPermissionDenied {
                statuses[player, default: PlayerStatus()].permissionDenied = true
            }
        }
    }

    private func handlePlayerNotification(_ player: MediaPlayer, info: [String: String]) {
        let state = PlaybackState(info["Player State"])
        let track = state == .stopped
            ? nil
            : player.track(id: info["Track ID"], title: info["Name"], artist: info["Artist"], album: info["Album"])
        let wasDenied = statuses[player]?.permissionDenied == true
        apply(player, state: state, track: track)

        // Access may have been granted in System Settings since we last asked.
        if wasDenied {
            Task { await refresh(player) }
        }
    }

    private func apply(_ player: MediaPlayer, state: PlaybackState, track: TrackInfo?) {
        var status = statuses[player] ?? PlayerStatus()
        let trackChanged = status.track?.id != track?.id
        if state == .playing, status.state != .playing {
            status.lastStartedPlaying = Date()
        }
        status.state = state
        status.track = track
        if track == nil { status.artwork = nil }
        statuses[player] = status

        if let track, trackChanged || status.artwork == nil {
            loadArtwork(for: track, player: player)
        }
    }

    private func loadArtwork(for track: TrackInfo, player: MediaPlayer, attempt: Int = 0) {
        Task {
            let outcome = await artworkLoader.artwork(for: track, player: player)
            // The track may have changed while the artwork was loading.
            guard statuses[player]?.track?.id == track.id else { return }

            switch outcome {
            case .image(let image):
                statuses[player]?.artwork = image
            case .permissionDenied:
                statuses[player]?.artwork = nil
                statuses[player]?.permissionDenied = true
            case .unavailable:
                statuses[player]?.artwork = nil
                // Players sometimes announce a track before its artwork is ready.
                if attempt < 2 {
                    try? await Task.sleep(for: .seconds(1))
                    guard statuses[player]?.track?.id == track.id else { return }
                    loadArtwork(for: track, player: player, attempt: attempt + 1)
                }
            }
        }
    }

    private nonisolated static func stringValues(_ userInfo: [AnyHashable: Any]?) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in userInfo ?? [:] {
            guard let key = key as? String else { continue }
            result[key] = value as? String ?? "\(value)"
        }
        return result
    }

    // MARK: Previews

    /// Fills in sample data for design snapshots. Never used while running normally.
    func loadPreviewData(longTitle: Bool = false) {
        var status = PlayerStatus()
        status.state = .playing
        status.track = TrackInfo(id: "preview", title: longTitle ? "Midnight City (Eric Prydz Private Remix) [Extended Version]" : "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming")
        status.artwork = NSImage(size: NSSize(width: 96, height: 96), flipped: false) { rect in
            let gradient = NSGradient(colors: [
                NSColor(red: 1.0, green: 0.48, blue: 0.36, alpha: 1),
                NSColor(red: 0.47, green: 0.27, blue: 0.92, alpha: 1),
            ])
            gradient?.draw(in: rect, angle: 55)
            return true
        }
        statuses[.spotify] = status
    }
}
