import AppKit
import SwiftUI

/// Flags for rendering the dock off screen (see `SnapshotTool`), where
/// window-server effects such as glass and layer animations cannot be drawn.
@MainActor
enum DesignPreview {
    static var isSnapshot = false
}

/// The pill's surface: Liquid Glass on macOS 26 and later, classic vibrancy
/// before that, and a solid fill when Reduce Transparency is on. Adds the
/// ambient shadow and the one-pixel edge treatment.
struct GlassBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.displayScale) private var displayScale

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.cornerRadius, style: .continuous)
    }

    /// Exactly one device pixel, so borders stay sharp at any display scale.
    private var hairline: CGFloat { 1 / max(displayScale, 1) }

    var body: some View {
        ZStack {
            // Shadow drawn only outside the pill, so it never darkens the
            // translucent surface from underneath.
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(DesignTokens.ambientShadowOpacity),
                        radius: DesignTokens.ambientShadowRadius,
                        y: DesignTokens.ambientShadowOffset)
                .mask {
                    Rectangle()
                        .padding(-DesignTokens.shadowPadding)
                        .overlay { shape.blendMode(.destinationOut) }
                        .compositingGroup()
                }

            surface
        }
        // Inner highlight: brightest along the top, fading out toward the bottom
        // so the lower edge reads as a clean curve rather than a hard line.
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.30), .white.opacity(0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: hairline
            )
        )
        // Outer edge: one device pixel of dark outline keeps the silhouette
        // crisp against any wallpaper, which matters most on 1x displays.
        .overlay(
            shape
                .inset(by: -hairline)
                .strokeBorder(Color.black.opacity(0.32), lineWidth: hairline)
        )
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            shape.fill(Color(white: 0.12))
        } else if DesignPreview.isSnapshot {
            shape.fill(Color.black.opacity(0.72))
        } else if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(DesignTokens.glassTintOpacity)), in: shape)
        } else {
            VisualEffectBackground()
                .clipShape(shape)
        }
    }
}

/// Classic behind-window vibrancy for systems without Liquid Glass.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        // The panel is never key, so without this the material renders as flat grey.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
