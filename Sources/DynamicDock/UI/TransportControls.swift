import SwiftUI

/// Previous / play-pause / next, or a single "Allow Access" button when
/// macOS has refused Automation access to the player.
struct TransportControls: View {
    let media: MediaController

    var body: some View {
        if let player = media.playerNeedingPermission {
            Button("Allow \(player.displayName) Access") {
                media.openAutomationSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(Color.white.opacity(0.16)))
            .contentShape(Capsule())
        } else {
            HStack(spacing: 2) {
                ControlButton(symbol: "backward.fill", size: 15) { media.send(.previous) }
                ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 20) { media.send(.playPause) }
                ControlButton(symbol: "forward.fill", size: 15) { media.send(.next) }
            }
            .disabled(media.commandTarget == nil)
            .opacity(media.commandTarget == nil ? 0.35 : 1)
        }
    }
}

/// SF Symbol button with a soft hover circle and a springy press.
struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    // `@State` is a macro in this SDK and its plugin ships only with Xcode,
    // not the Command Line Tools, so the State storage is declared directly.
    private let isHovered = State(initialValue: false)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(isHovered.wrappedValue ? 0.14 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleStyle())
        .onHover { isHovered.wrappedValue = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered.wrappedValue)
    }
}

private struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
