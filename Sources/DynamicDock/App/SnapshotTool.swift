import AppKit
import SwiftUI

/// Development aid: renders the dock to a PNG and exits, so the design can be
/// inspected without the cursor being on the screen edge.
///
/// - `DynamicDock --snapshot <path.png> [scale]` uses sample track data.
/// - `DynamicDock --live-snapshot <path.png> [scale]` uses whatever Spotify
///   or Music is playing, including its real artwork.
@MainActor
enum SnapshotTool {
    /// Returns true when a snapshot was requested (and the app should exit).
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--snapshot"), arguments.count > flag + 1 else {
            return false
        }
        let path = arguments[flag + 1]
        let scale = arguments.count > flag + 2 ? Double(arguments[flag + 2]) ?? 2 : 2

        let media = MediaController()
        if !arguments.contains("--empty") { media.loadPreviewData(longTitle: arguments.contains("--long")) }
        render(media: media, to: path, scale: scale)
        return true
    }

    /// Starts watching the players, waits for a track and its artwork, then
    /// renders. Returns true when a live snapshot was requested.
    static func runLiveIfRequested(media: MediaController) -> Bool {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--live-snapshot"), arguments.count > flag + 1 else {
            return false
        }
        let path = arguments[flag + 1]
        let scale = arguments.count > flag + 2 ? Double(arguments[flag + 2]) ?? 2 : 2

        media.start()
        Task {
            // Allow time for the Automation prompt to be answered.
            for _ in 0..<480 where media.artwork == nil {
                try? await Task.sleep(for: .milliseconds(250))
            }
            render(media: media, to: path, scale: scale)
            exit(media.artwork == nil ? 1 : 0)
        }
        return true
    }

    private static func render(media: MediaController, to path: String, scale: Double) {
        DesignPreview.isSnapshot = true
        let visibility = DockVisibility()
        visibility.isShown = true
        let backdrop = LinearGradient(
            colors: [
                Color(red: 0.33, green: 0.40, blue: 0.93),
                Color(red: 0.80, green: 0.44, blue: 0.76),
                Color(red: 1.00, green: 0.70, blue: 0.52),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let dock = MusicDockView(visibility: visibility, media: media)
            .frame(width: DesignTokens.panelSize.width, height: DesignTokens.panelSize.height)
            .environment(\.colorScheme, .dark)

        // `--social` lays the dock out on a 2:1 card with the icon and name,
        // the shape GitHub uses for a repository's social preview.
        let content: AnyView
        if CommandLine.arguments.contains("--social") {
            content = AnyView(
                VStack(spacing: 0) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 84, height: 84)
                    Text("Dynamic Dock")
                        .font(.system(size: 34, weight: .bold))
                        .padding(.top, 2)
                    Text("A floating music dock for macOS")
                        .font(.system(size: 15, weight: .medium))
                        .opacity(0.85)
                        .padding(.top, 4)
                    dock
                        .scaleEffect(1.15)
                        .padding(.top, 2)
                }
                .foregroundStyle(.white)
                .frame(width: 640, height: 320)
                .environment(\.displayScale, scale)
                .background(backdrop)
            )
        } else {
            content = AnyView(
                dock
                    .environment(\.displayScale, scale)
                    .background(backdrop)
            )
        }

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("snapshot failed\n".utf8))
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
