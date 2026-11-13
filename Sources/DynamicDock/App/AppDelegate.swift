import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dockController: DockPanelController?
    private let media = MediaController()
    private var settingsWindow: NSWindow?

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

        let controller = DockPanelController(media: media)
        controller.start()
        dockController = controller
    }

    func showSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView(settings: .shared))
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Dynamic Dock Settings"
            window.isReleasedWhenClosed = false
            window.contentView = hostingView
            window.center()
            settingsWindow = window
        }
        // An agent app is never frontmost on its own, so bring the window forward explicitly.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
