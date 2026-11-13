import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockController: DockPanelController?
    private let media = MediaController()
    private var settingsWindow: NSWindow?
    private var nowPlaying: NowPlayingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if SnapshotTool.runIfRequested() {
            exit(0)
        }

        // LSUIElement in Info.plist already makes this an agent app; setting the
        // policy here keeps the same behaviour when the bare binary is run
        // outside the bundle (e.g. `swift run`).
        NSApp.setActivationPolicy(.accessory)

        if SnapshotTool.runLiveIfRequested(media: media) {
            return
        }

        // Development aid: open only the settings window, so it can be
        // checked without the menu bar, the dock or any player access.
        if let flag = CommandLine.arguments.firstIndex(of: "--settings-window-snapshot"),
           CommandLine.arguments.count > flag + 1 {
            let path = CommandLine.arguments[flag + 1]
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                snapshotSettingsWindow(to: path)
                exit(0)
            }
            return
        }

        if CommandLine.arguments.contains("--show-settings") {
            showSettings()
            return
        }

        // Development aid: install the latest release without the settings
        // window. Exits with 1 when there was nothing to install.
        if CommandLine.arguments.contains("--self-update") {
            Task {
                await Updater.shared.check()
                await Updater.shared.install()
                exit(1)
            }
            return
        }

        media.start()

        let nowPlaying = NowPlayingWindowController(media: media)
        self.nowPlaying = nowPlaying

        let controller = DockPanelController(media: media)
        controller.onOpenNowPlaying = { screen in nowPlaying.open(on: screen) }
        controller.start()
        dockController = controller
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = makeSettingsWindow()
            window.center()
            settingsWindow = window
        }
        // An agent app is never frontmost on its own, so bring the window forward explicitly.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hostingView = NSHostingView(rootView: SettingsView(settings: .shared))
        // The view lays itself out under the title bar; without this the
        // hosting view insets it and the surface stops partway up the bar.
        hostingView.safeAreaRegions = []
        let size = hostingView.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Dynamic Dock Settings"
        window.isReleasedWhenClosed = false
        // The content runs up under a transparent title bar, in dark mode always.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        // The window has a fixed size, so the green zoom button would only
        // ever show as a greyed-out dot. Leave it out.
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // The glass is an AppKit blur view behind the content. A window
        // made transparent for SwiftUI glass lets clicks fall through it.
        let blur = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        // Stays the same whether or not the window has focus.
        blur.state = .active
        hostingView.frame = blur.bounds
        hostingView.autoresizingMask = [.width, .height]
        blur.addSubview(hostingView)
        window.contentView = blur
        window.setContentSize(size)
        return window
    }

    /// Development aid: draws the real settings window, title bar included,
    /// into a PNG. The blur itself cannot be captured and comes out dark.
    private func snapshotSettingsWindow(to path: String) {
        let window = makeSettingsWindow()
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFrontRegardless()
        window.displayIfNeeded()
        guard let frameView = window.contentView?.superview,
              let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds)
        else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
