import AppKit

/// Reports every cursor movement, wherever it happens. The global monitor
/// covers other apps; the local monitor covers our own panel, where global
/// monitors do not fire. Mouse-move monitors need no Accessibility permission.
@MainActor
final class EdgeTriggerMonitor {
    var onMouseMoved: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private static let mask: NSEvent.EventTypeMask = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
    ]

    func start() {
        guard globalMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: Self.mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.onMouseMoved?() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: Self.mask) { [weak self] event in
            MainActor.assumeIsolated { self?.onMouseMoved?() }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
