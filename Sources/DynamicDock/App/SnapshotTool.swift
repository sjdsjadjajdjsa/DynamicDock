import AppKit
import SwiftUI

/// Development aid: `DynamicDock --snapshot <path.png> [scale]` renders the
/// dock to a PNG and exits, so the design can be inspected without the
/// cursor being on the screen edge.
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

        DesignPreview.isSnapshot = true
        let visibility = DockVisibility()
        visibility.isShown = true
        let media = MediaController()
        if !arguments.contains("--empty") { media.loadPreviewData(longTitle: arguments.contains("--long")) }
        let content = MusicDockView(visibility: visibility, media: media)
            .frame(width: DesignTokens.panelSize.width, height: DesignTokens.panelSize.height)
            .environment(\.displayScale, scale)
            .environment(\.colorScheme, .dark)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.33, green: 0.40, blue: 0.93),
                        Color(red: 0.80, green: 0.44, blue: 0.76),
                        Color(red: 1.00, green: 0.70, blue: 0.52),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("snapshot failed\n".utf8))
            return true
        }
        try? data.write(to: URL(fileURLWithPath: path))
        return true
    }
}
