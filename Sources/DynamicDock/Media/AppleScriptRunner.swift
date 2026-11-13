import AppKit
import CoreServices

struct ScriptOutput: Sendable {
    /// List items for a list result, or the single value as text.
    var strings: [String] = []
    /// Raw bytes of a non-list result (used for artwork).
    var data: Data?
}

struct ScriptError: Error, Sendable {
    let code: Int

    /// The user has not allowed (or has denied) Automation access.
    var isPermissionDenied: Bool { code == Int(errAEEventNotPermitted) }
}

/// Runs AppleScript on one dedicated thread. NSAppleScript is not safe to use
/// from arbitrary threads, and a slow or hung player must never block the UI.
final class AppleScriptRunner: @unchecked Sendable {
    static let shared = AppleScriptRunner()

    private let condition = NSCondition()
    private var jobs: [@Sendable () -> Void] = []
    /// Compiled scripts by source. Only touched on the worker thread.
    private var compiled: [String: NSAppleScript] = [:]

    private init() {
        let thread = Thread { [self] in workLoop() }
        thread.name = "DynamicDock.AppleScript"
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    private func workLoop() {
        while true {
            condition.lock()
            while jobs.isEmpty { condition.wait() }
            let job = jobs.removeFirst()
            condition.unlock()
            autoreleasepool { job() }
        }
    }

    private func enqueue(_ job: @escaping @Sendable () -> Void) {
        condition.lock()
        jobs.append(job)
        condition.signal()
        condition.unlock()
    }

    func run(_ source: String) async -> Result<ScriptOutput, ScriptError> {
        await withCheckedContinuation { continuation in
            enqueue { continuation.resume(returning: self.execute(source)) }
        }
    }

    /// Asks macOS whether we may automate the app, showing the consent prompt
    /// the first time. Returns `noErr`, `errAEEventNotPermitted`, or another
    /// status such as `procNotFound` when the app is not running.
    func automationPermission(for bundleID: String) async -> OSStatus {
        await withCheckedContinuation { continuation in
            enqueue {
                let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
                let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
                continuation.resume(returning: status)
            }
        }
    }

    private func execute(_ source: String) -> Result<ScriptOutput, ScriptError> {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return .failure(ScriptError(code: -1)) }
            var compileError: NSDictionary?
            guard fresh.compileAndReturnError(&compileError) else {
                return .failure(ScriptError(code: Self.code(from: compileError)))
            }
            compiled[source] = fresh
            script = fresh
        }

        var runError: NSDictionary?
        let result = script.executeAndReturnError(&runError)
        if runError != nil {
            return .failure(ScriptError(code: Self.code(from: runError)))
        }

        var output = ScriptOutput()
        if result.descriptorType == typeAEList {
            let count = result.numberOfItems
            if count > 0 {
                output.strings = (1...count).map { result.atIndex($0)?.stringValue ?? "" }
            }
        } else {
            if let text = result.stringValue { output.strings = [text] }
            output.data = result.data
        }
        return .success(output)
    }

    private static func code(from error: NSDictionary?) -> Int {
        (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? -1
    }
}
