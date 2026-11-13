// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift Scripts/make-icon.swift [preview.png]
// With a path argument it also saves the 1024px master image there.
import AppKit
import SwiftUI

/// Master artwork on the standard macOS grid: a 1024pt canvas holding an
/// 824pt rounded square, which leaves room for the icon's own shadow.
struct IconView: View {
    private let plate = RoundedRectangle(cornerRadius: 185, style: .continuous)
    private let pill = RoundedRectangle(cornerRadius: 104, style: .continuous)
    private let barHeights: [CGFloat] = [92, 164, 212, 140, 72]

    var body: some View {
        ZStack {
            // Background plate: deep indigo fading to near-black, with a
            // soft glow rising from the bottom edge where the dock lives.
            plate
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.17, green: 0.18, blue: 0.30), Color(red: 0.03, green: 0.03, blue: 0.07)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RadialGradient(
                        colors: [Color(red: 0.48, green: 0.42, blue: 1.0).opacity(0.75), .clear],
                        center: UnitPoint(x: 0.5, y: 1.05),
                        startRadius: 0,
                        endRadius: 560
                    )
                    .clipShape(plate)
                )
                .overlay(
                    plate.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 5
                    )
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.32), radius: 20, y: 12)

            // The dock itself: a glass pill holding the visualizer bars.
            ZStack {
                pill
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.26), .white.opacity(0.10)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        pill.strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 5
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 16)

                HStack(spacing: 36) {
                    ForEach(0..<barHeights.count, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.white, Color(red: 0.80, green: 0.84, blue: 1.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 46, height: barHeights[index])
                    }
                }
                .shadow(color: Color(red: 0.55, green: 0.5, blue: 1.0).opacity(0.7), radius: 22)
            }
            .frame(width: 660, height: 304)
        }
        .frame(width: 1024, height: 1024)
    }
}

func png(_ image: CGImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.cgContext.interpolationQuality = .high
    context.cgContext.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return rep.representation(using: .png, properties: [:])!
}

@MainActor
func makeIcon() throws {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1
    guard let master = renderer.cgImage else { fatalError("could not render the icon") }

    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    for points in [16, 32, 128, 256, 512] {
        try png(master, pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
        try png(master, pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
    }

    let output = root.appendingPathComponent("Resources/AppIcon.icns")
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
    try iconutil.run()
    iconutil.waitUntilExit()
    try? FileManager.default.removeItem(at: iconset)
    guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
    print("Wrote \(output.path)")

    if CommandLine.arguments.count > 1 {
        try png(master, pixels: 1024).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}

try MainActor.assumeIsolated { try makeIcon() }
