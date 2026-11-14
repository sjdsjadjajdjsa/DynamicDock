import AppKit
import SwiftUI

/// Borderless window that covers one screen and takes the keyboard, so Esc
/// closes it and Space plays or pauses.
final class NowPlayingWindow: NSWindow {
    var onClose: (() -> Void)?
    var onPlayPause: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onClose?()      // Esc
        case 49: onPlayPause?()  // Space
        default: super.keyDown(with: event)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }
}

/// Opens and closes the full-screen now-playing view, and listens to the
/// system's audio only while it is open.
@MainActor
final class NowPlayingWindowController {
    private static let fadeDuration: TimeInterval = 0.25

    private let media: MediaController
    private let spectrum = AudioSpectrum()
    private let lyrics: LyricsController
    /// A `SystemAudioTap`, held untyped because it needs macOS 14.2.
    private var tap: AnyObject?
    private var window: NowPlayingWindow?
    /// The app that was in front, so focus can go back to it.
    private var previousApp: NSRunningApplication?
    /// Counts opens, so a finished close animation never hides a newer window.
    private var generation = 0

    init(media: MediaController) {
        self.media = media
        lyrics = LyricsController(media: media)
    }

    func open(on screen: NSScreen) {
        guard window == nil else { return }
        generation += 1
        previousApp = NSWorkspace.shared.frontmostApplication

        let window = NowPlayingWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.onClose = { [weak self] in self?.close() }
        window.onPlayPause = { [weak self] in self?.media.send(.playPause) }
        window.contentView = NSHostingView(
            rootView: NowPlayingView(media: media, spectrum: spectrum, lyrics: lyrics) { [weak self] in self?.close() }
        )
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // No control starts focused, so nothing is ringed and Space reaches the window.
        window.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            window.animator().alphaValue = 1
        }

        startListening()
        lyrics.start()
    }

    func close() {
        guard let window else { return }
        self.window = nil
        stopListening()
        lyrics.stop()

        let closing = generation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                window.orderOut(nil)
                // Hand focus back, unless the view was reopened meanwhile.
                if let self, self.generation == closing {
                    self.previousApp?.activate()
                    self.previousApp = nil
                }
            }
        })
    }

    private func startListening() {
        guard #available(macOS 14.2, *) else { return }
        let tap = SystemAudioTap()
        do {
            try tap.start(feeding: spectrum)
            self.tap = tap
        } catch {
            // The view still works: the bars fall back to simulated motion.
            NSLog("Dynamic Dock: system audio is unavailable: \(error)")
        }
    }

    private func stopListening() {
        if #available(macOS 14.2, *) {
            (tap as? SystemAudioTap)?.stop()
        }
        // Diagnostic: records whether the bars were following real audio.
        if tap != nil {
            NSLog("Dynamic Dock: visualizer closed, real audio %@", spectrum.snapshot().hasSignal ? "received" : "not received")
        }
        tap = nil
        spectrum.reset()
    }
}
