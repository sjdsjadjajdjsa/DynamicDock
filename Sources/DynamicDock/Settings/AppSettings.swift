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
    }

    static let revealDelayRange: ClosedRange<Double> = 0...0.6
    static let hideDelayRange: ClosedRange<Double> = 0.1...1.5

    /// Seconds the cursor must rest on the bottom edge before the dock shows.
    var revealDelay: Double {
        didSet { defaults.set(revealDelay, forKey: Key.revealDelay) }
    }

    /// Seconds the cursor may stay away before the dock hides.
    var hideDelay: Double {
        didSet { defaults.set(hideDelay, forKey: Key.hideDelay) }
    }

    /// Whether the whole bottom edge reveals the dock, rather than its centre.
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
        ])
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
