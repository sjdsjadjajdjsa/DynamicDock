import AppKit
import SwiftUI

/// Borderless, non-activating panel that floats above the Dock on every Space
/// (including full-screen apps) and never takes keyboard focus.
final class FloatingDockPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // isFloatingPanel resets the level to .floating, so set the level after it.
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // The pill draws its own shadow; window shadows on transparent windows glitch.
        hasShadow = false
        isMovable = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        // The dock is a dark HUD in both light and dark mode, like the
        // Dynamic Island, so its text and glass always resolve as dark.
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The panel deliberately hangs below the screen edge (shadow padding now,
    /// slide travel later), so AppKit must not push it back on screen.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Hosting view whose controls respond to the first click even though the
/// panel is never key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
