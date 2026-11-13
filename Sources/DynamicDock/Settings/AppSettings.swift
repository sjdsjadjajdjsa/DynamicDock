import Foundation
import ServiceManagement

/// User preferences, saved to UserDefaults as they change.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let revealDelay = "revealDelay"
        static let hideDelay = "hideDelay"
        static let fullWidthTrigger = "fullWidthTrigger"
        static let edge = "edge"
        static let position = "position"
        static let edgeMargin = "edgeMargin"
    }

    static let revealDelayRange: ClosedRange<Double> = 0...0.6
    static let hideDelayRange: ClosedRange<Double> = 0.1...1.5
    static let edgeMarginRange: ClosedRange<Double> = 4...80

    /// Screen edge the dock lives on.
    var edge: DockEdge {
        didSet {
            defaults.set(edge.rawValue, forKey: Key.edge)
            onLayoutChange?()
        }
    }

    /// Place along the edge, 0...1: left to right on the bottom edge, bottom
    /// to top on the side edges.
    var position: Double {
        didSet {
            defaults.set(position, forKey: Key.position)
            onLayoutChange?()
        }
    }

    /// Gap between the dock and the screen edge, in points.
    var edgeMargin: Double {
        didSet {
            defaults.set(edgeMargin, forKey: Key.edgeMargin)
            onLayoutChange?()
        }
    }

    /// Called after a setting that moves the dock changes.
    @ObservationIgnored var onLayoutChange: (() -> Void)?

    var layout: DockLayout {
        DockLayout(edge: edge, position: position, margin: edgeMargin, fullEdgeTrigger: fullWidthTrigger)
    }

    /// Seconds the cursor must rest on the edge before the dock shows.
    var revealDelay: Double {
        didSet { defaults.set(revealDelay, forKey: Key.revealDelay) }
    }

    /// Seconds the cursor may stay away before the dock hides.
    var hideDelay: Double {
        didSet { defaults.set(hideDelay, forKey: Key.hideDelay) }
    }

    /// Whether the whole edge reveals the dock, rather than the part near it.
    var fullWidthTrigger: Bool {
        didSet { defaults.set(fullWidthTrigger, forKey: Key.fullWidthTrigger) }
    }

    /// Mirrors the system's login-item state for this app.
    private(set) var launchAtLogin: Bool
    /// Why the last attempt to change the login item failed, if it did.
    private(set) var launchAtLoginError: String?

    @ObservationIgnored private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [
            Key.revealDelay: DesignTokens.defaultRevealDelay,
            Key.hideDelay: DesignTokens.defaultHideDelay,
            Key.fullWidthTrigger: false,
            Key.position: 0.5,
            Key.edgeMargin: Double(DesignTokens.defaultEdgeMargin),
        ])
        edge = defaults.string(forKey: Key.edge).flatMap(DockEdge.init(rawValue:)) ?? .bottom
        position = min(max(defaults.double(forKey: Key.position), 0), 1)
        edgeMargin = min(
            max(defaults.double(forKey: Key.edgeMargin), Self.edgeMarginRange.lowerBound),
            Self.edgeMarginRange.upperBound
        )
        revealDelay = defaults.double(forKey: Key.revealDelay)
        hideDelay = defaults.double(forKey: Key.hideDelay)
        fullWidthTrigger = defaults.bool(forKey: Key.fullWidthTrigger)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Re-reads the login-item state, which can also be changed in System Settings.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
