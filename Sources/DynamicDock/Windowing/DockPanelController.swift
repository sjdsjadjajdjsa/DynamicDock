import AppKit
import SwiftUI

/// Drives the SwiftUI slide animation.
@MainActor
@Observable
final class DockVisibility {
    var isShown = false
    /// When the dock was last revealed; scrolling text restarts from here.
    var shownAt = Date.distantPast
}

/// Owns the floating panel and runs the show/hide state machine:
/// hidden → (cursor dwells on the bottom edge) → shown → (cursor stays away
/// for the grace delay) → hidden.
@MainActor
final class DockPanelController: NSObject {
    private enum State { case hidden, shown }

    private let panel: FloatingDockPanel
    private let visibility = DockVisibility()
    private let monitor = EdgeTriggerMonitor()
    private let settings = AppSettings.shared

    private var state: State = .hidden
    /// Frames of the screen the dock is currently shown on.
    private var activeScreen: (frame: CGRect, visibleFrame: CGRect)?

    private var dwellTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var orderOutTask: Task<Void, Never>?

    init(media: MediaController) {
        panel = FloatingDockPanel(contentRect: NSRect(origin: .zero, size: DesignTokens.panelSize))
        super.init()

        let hostingView = FirstMouseHostingView(rootView: MusicDockView(visibility: visibility, media: media))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.ignoresMouseEvents = true
        // Render the hidden state once so the first reveal animates from it.
        hostingView.layoutSubtreeIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenLayoutDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    /// Begins watching the cursor. The dock stays hidden until triggered.
    func start() {
        monitor.onMouseMoved = { [weak self] in self?.mouseMoved() }
        monitor.start()
    }

    // MARK: Mouse handling

    private func mouseMoved() {
        switch state {
        case .hidden: evaluateTrigger()
        case .shown: evaluateKeepAlive()
        }
    }

    private func triggerRect(on screenFrame: CGRect) -> CGRect {
        ScreenGeometry.triggerRect(screenFrame: screenFrame, fullWidth: settings.fullWidthTrigger)
    }

    /// The screen whose trigger strip the cursor is on, if any.
    private func triggeredScreen() -> NSScreen? {
        // Ignore the edge while dragging, so drags near the bottom don't reveal the dock.
        guard NSEvent.pressedMouseButtons == 0 else { return nil }
        let location = NSEvent.mouseLocation
        guard let screen = ScreenGeometry.screen(containing: location),
              ScreenGeometry.inclusiveContains(triggerRect(on: screen.frame), location)
        else { return nil }
        return screen
    }

    private func evaluateTrigger() {
        guard let screen = triggeredScreen() else {
            dwellTask?.cancel()
            dwellTask = nil
            return
        }
        guard dwellTask == nil else { return }

        let stacked = ScreenGeometry.hasScreenBelow(
            NSEvent.mouseLocation,
            screenFrame: screen.frame,
            allFrames: NSScreen.screens.map(\.frame)
        )
        let dwell = stacked
            ? max(settings.revealDelay, DesignTokens.stackedDisplayDwell)
            : settings.revealDelay

        dwellTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(dwell))
            guard !Task.isCancelled, let self else { return }
            self.dwellTask = nil
            // The cursor may have stopped moving, so re-read it rather than wait for an event.
            if self.state == .hidden, let screen = self.triggeredScreen() {
                self.show(on: screen)
            }
        }
    }

    private func cursorIsOverDock() -> Bool {
        guard let activeScreen else { return false }
        let location = NSEvent.mouseLocation
        let keepAlive = ScreenGeometry.keepAliveRect(
            screenFrame: activeScreen.frame,
            visibleFrame: activeScreen.visibleFrame
        )
        // The trigger strip also counts, so resting where you triggered keeps the dock open.
        return ScreenGeometry.inclusiveContains(keepAlive, location)
            || ScreenGeometry.inclusiveContains(triggerRect(on: activeScreen.frame), location)
    }

    private func evaluateKeepAlive() {
        if cursorIsOverDock() {
            hideTask?.cancel()
            hideTask = nil
        } else if hideTask == nil {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.settings.hideDelay ?? DesignTokens.defaultHideDelay))
            guard !Task.isCancelled, let self else { return }
            self.hideTask = nil
            guard self.state == .shown, !self.cursorIsOverDock() else { return }
            if NSEvent.pressedMouseButtons != 0 {
                // Mid-click or mid-drag: check again after another grace period.
                self.scheduleHide()
            } else {
                self.hide()
            }
        }
    }

    // MARK: Show / hide

    private func show(on screen: NSScreen) {
        orderOutTask?.cancel()
        orderOutTask = nil

        activeScreen = (screen.frame, screen.visibleFrame)
        panel.setFrame(
            ScreenGeometry.panelFrame(screenFrame: screen.frame, visibleFrame: screen.visibleFrame),
            display: true
        )
        panel.ignoresMouseEvents = false
        // Never activate the app: the panel must not steal focus.
        panel.orderFrontRegardless()
        state = .shown

        // Flip the flag on the next turn so the window is on screen in its
        // hidden pose before the spring starts.
        Task { [weak self] in
            guard let self else { return }
            guard self.state == .shown else { return }
            self.visibility.shownAt = Date()
            self.visibility.isShown = true
        }
    }

    private func hide() {
        hideTask?.cancel()
        hideTask = nil
        state = .hidden
        visibility.isShown = false
        panel.ignoresMouseEvents = true

        orderOutTask?.cancel()
        orderOutTask = Task { [weak self] in
            try? await Task.sleep(for: DesignTokens.orderOutDelay)
            guard !Task.isCancelled, let self else { return }
            self.orderOutTask = nil
            if self.state == .hidden {
                self.panel.orderOut(nil)
            }
        }
    }

    @objc private func screenLayoutDidChange() {
        // Screens were added, removed or rearranged: the cached frames are stale.
        if state == .shown { hide() }
    }
}
