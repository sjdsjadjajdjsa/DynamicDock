import SwiftUI

@main
struct DynamicDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Dynamic Dock", systemImage: "music.note") {
            Button("Settings…") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Dynamic Dock") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
