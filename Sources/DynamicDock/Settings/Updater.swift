import AppKit

/// Checks GitHub for a newer release and, on request, downloads it, swaps
/// it in for the running app and relaunches.
@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case installing
        case failed(String)
    }

    private(set) var state: State = .idle

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    @ObservationIgnored private var downloadURL: URL?

    private static let latestRelease = URL(
        string: "https://api.github.com/repos/sjdsjadjajdjsa/DynamicDock/releases/latest"
    )!
    private static let assetName = "DynamicDock.zip"

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let assets: [Asset]
    }

    private struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    private init() {}

    /// Asks GitHub for the latest release and compares it with this version.
    func check() async {
        guard state != .checking, state != .installing else { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.latestRelease)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw Failure("Could not reach GitHub.")
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name

            guard latest.compare(currentVersion, options: .numeric) == .orderedDescending else {
                state = .upToDate
                return
            }
            guard let asset = release.assets.first(where: { $0.name == Self.assetName }) else {
                throw Failure("Version \(latest) has no download yet.")
            }
            downloadURL = asset.browser_download_url
            state = .available(version: latest)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Downloads the release found by `check()`, replaces this app with it
    /// and relaunches.
    func install() async {
        guard case .available = state, let downloadURL else { return }
        state = .installing
        do {
            let target = Bundle.main.bundleURL
            guard target.pathExtension == "app", let bundleID = Bundle.main.bundleIdentifier else {
                throw Failure("This copy is not running from an app bundle.")
            }

            let (archive, response) = try await URLSession.shared.download(from: downloadURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw Failure("The download failed.")
            }

            let newApp = try await Task.detached {
                try Self.unpack(archive: archive, expectedBundleID: bundleID)
            }.value

            _ = try FileManager.default.replaceItemAt(target, withItemAt: newApp)
            try relaunch(target)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Unzips the download and checks it is an intact copy of this app.
    private nonisolated static func unpack(archive: URL, expectedBundleID: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("DynamicDockUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, folder.path])

        let app = folder.appendingPathComponent("DynamicDock.app")
        guard Bundle(url: app)?.bundleIdentifier == expectedBundleID else {
            throw Failure("The download is not Dynamic Dock.")
        }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure("The update could not be unpacked or is damaged.")
        }
    }

    /// Starts a helper that waits for this process to exit and then opens
    /// the new copy, and quits.
    private func relaunch(_ app: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c",
            "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"",
            app.path,
        ]
        try helper.run()
        NSApp.terminate(nil)
    }
}
