import AppKit
import SwiftUI

/// Colours and metrics of the settings window: custom cards and controls on
/// a blurred, dark-tinted window, instead of the stock form materials.
enum SettingsStyle {
    static let background = Color(red: 0.086, green: 0.086, blue: 0.102)
    static let card = Color.white.opacity(0.07)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(red: 0.52, green: 0.47, blue: 0.98)
    static let width: CGFloat = 440
    static let rowHeight: CGFloat = 46
    static let cardRadius: CGFloat = 14
}

struct SettingsView: View {
    let settings: AppSettings
    private let updater = Updater.shared

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            card {
                row("Open at login") {
                    SettingsToggle(isOn: settings.launchAtLogin) { settings.setLaunchAtLogin($0) }
                }
            }
            if let error = settings.launchAtLoginError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
            }

            sectionTitle("Position")
            card {
                row("Screen edge") {
                    SettingsSegments(
                        options: [("Left", DockEdge.left), ("Bottom", .bottom), ("Right", .right)],
                        selection: settings.edge
                    ) { settings.edge = $0 }
                    .frame(width: 216)
                }
                divider
                // 0 is the left end of the bottom edge, or the bottom of a side edge.
                sliderRow(
                    settings.edge.isVertical ? "Height on screen" : "Position along edge",
                    value: settings.position,
                    range: 0...1,
                    label: String(format: "%.0f%%", settings.position * 100)
                ) { settings.position = $0 }
                divider
                sliderRow(
                    "Distance from edge",
                    value: settings.edgeMargin,
                    range: AppSettings.edgeMarginRange,
                    label: String(format: "%.0f pt", settings.edgeMargin)
                ) { settings.edgeMargin = $0.rounded() }
            }

            sectionTitle("Showing the dock")
            card {
                row("Reveal from") {
                    SettingsSegments(
                        options: [("Near the dock", false), ("Entire edge", true)],
                        selection: settings.fullWidthTrigger
                    ) { settings.fullWidthTrigger = $0 }
                    .frame(width: 216)
                }
                divider
                sliderRow(
                    "Reveal delay",
                    value: settings.revealDelay,
                    range: AppSettings.revealDelayRange,
                    label: String(format: "%.2f s", settings.revealDelay)
                ) { settings.revealDelay = $0 }
                divider
                sliderRow(
                    "Hide delay",
                    value: settings.hideDelay,
                    range: AppSettings.hideDelayRange,
                    label: String(format: "%.2f s", settings.hideDelay)
                ) { settings.hideDelay = $0 }
            }

            sectionTitle("Updates")
            card {
                row(updateStatus) { updateControl }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .frame(width: SettingsStyle.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(SettingsSurface())
        .environment(\.colorScheme, .dark)
        .onAppear {
            settings.refreshLaunchAtLogin()
            Task { await updater.check() }
        }
    }

    // MARK: Pieces

    private var hairline: CGFloat { 1 / max(displayScale, 1) }

    /// App icon, name and version. The top padding clears the window buttons.
    private var header: some View {
        HStack(spacing: 12) {
            SettingsIcon(side: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dynamic Dock")
                    .font(.system(size: 17, weight: .semibold))
                Text("Version \(updater.currentVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 38)
        .padding(.bottom, 18)
        .padding(.horizontal, 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: SettingsStyle.cardRadius, style: .continuous)
        return VStack(spacing: 0, content: content)
            .background(shape.fill(SettingsStyle.card))
            .overlay(shape.strokeBorder(SettingsStyle.line, lineWidth: hairline))
    }

    private var divider: some View {
        Rectangle()
            .fill(SettingsStyle.line)
            .frame(height: hairline)
            .padding(.leading, 14)
    }

    private func row(_ title: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .lineLimit(2)
            Spacer(minLength: 8)
            control()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: SettingsStyle.rowHeight)
    }

    private func sliderRow(_ title: String, value: Double, range: ClosedRange<Double>,
                           label: String, onChange: @escaping (Double) -> Void) -> some View {
        row(title) {
            SettingsSlider(value: value, range: range, onChange: onChange)
                .frame(width: 160, height: 22)
            Text(label)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    // MARK: Updates

    private var updateStatus: String {
        switch updater.state {
        case .idle: return "Not checked yet"
        case .checking: return "Checking for updates…"
        case .upToDate: return "You have the latest version."
        case .available(let version): return "Version \(version) is available."
        case .installing: return "Updating…"
        case .failed(let message): return message
        }
    }

    @ViewBuilder
    private var updateControl: some View {
        switch updater.state {
        case .available:
            SettingsButton(title: "Update Now", prominent: true) { Task { await updater.install() } }
        case .checking, .installing:
            ProgressView().controlSize(.small)
        case .idle, .upToDate, .failed:
            SettingsButton(title: "Check for Updates", prominent: false) { Task { await updater.check() } }
        }
    }
}

/// Dark tint over the window's blur (see `AppDelegate.showSettings`), or a
/// solid fill for Reduce Transparency and design snapshots.
private struct SettingsSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency || DesignPreview.isSnapshot {
            SettingsStyle.background
        } else {
            Color.black.opacity(0.28)
        }
    }
}

/// The app icon drawn as vectors at its display size. The icon file is not
/// used here: scaled down, its bright top rim turns into pale corners, and
/// the system adds a plate of its own to small app icons.
private struct SettingsIcon: View {
    let side: CGFloat

    private static let barHeights: [CGFloat] = [92, 164, 212, 140, 72]

    var body: some View {
        // Proportions follow Scripts/make-icon.swift, whose plate is 824 units.
        let unit = side / 824
        let plate = RoundedRectangle(cornerRadius: 185 * unit, style: .continuous)
        let pill = RoundedRectangle(cornerRadius: 104 * unit, style: .continuous)

        ZStack {
            plate.fill(
                LinearGradient(
                    colors: [Color(red: 0.17, green: 0.18, blue: 0.30), Color(red: 0.03, green: 0.03, blue: 0.07)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            RadialGradient(
                colors: [Color(red: 0.48, green: 0.42, blue: 1.0).opacity(0.75), .clear],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 0,
                endRadius: 560 * unit
            )
            .clipShape(plate)

            pill.fill(Color.white.opacity(0.18))
                .frame(width: 660 * unit, height: 304 * unit)

            HStack(spacing: 36 * unit) {
                ForEach(Self.barHeights.indices, id: \.self) { index in
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 46 * unit, height: Self.barHeights[index] * unit)
                }
            }
        }
        .frame(width: side, height: side)
        // An even, faint edge all the way round, with no bright rim on top.
        .overlay(plate.strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Capsule switch.
private struct SettingsToggle: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            onChange(!isOn)
        } label: {
            Capsule()
                .fill(isOn ? SettingsStyle.accent : Color.white.opacity(0.14))
                .frame(width: 40, height: 24)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                        .padding(2)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isOn)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

/// Segmented choice with a highlight that slides to the selected option.
private struct SettingsSegments<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    let selection: Value
    let onSelect: (Value) -> Void

    var body: some View {
        GeometryReader { proxy in
            let segment = (proxy.size.width - 4) / CGFloat(options.count)
            let index = options.firstIndex { $0.value == selection } ?? 0

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(Color.white.opacity(0.17))
                    .frame(width: segment, height: proxy.size.height - 4)
                    .offset(x: 2 + segment * CGFloat(index))
                    .animation(.spring(response: 0.3, dampingFraction: 0.82), value: index)

                HStack(spacing: 0) {
                    ForEach(options.indices, id: \.self) { item in
                        Button {
                            onSelect(options[item].value)
                        } label: {
                            Text(options[item].title)
                                .font(.system(size: 12, weight: item == index ? .semibold : .regular))
                                .foregroundStyle(item == index ? .primary : .secondary)
                                .frame(width: segment, height: proxy.size.height)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 28)
    }
}

/// Thin track with a round knob.
private struct SettingsSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void

    private static let knob: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let usable = max(proxy.size.width - Self.knob, 1)
            let span = range.upperBound - range.lowerBound
            let fraction = CGFloat(min(max((value - range.lowerBound) / span, 0), 1))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)
                Capsule()
                    .fill(SettingsStyle.accent)
                    .frame(width: Self.knob / 2 + usable * fraction, height: 4)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .frame(width: Self.knob, height: Self.knob)
                    .offset(x: usable * fraction)
            }
            .frame(height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { drag in
                    let position = min(max((drag.location.x - Self.knob / 2) / usable, 0), 1)
                    onChange(range.lowerBound + Double(position) * span)
                }
            )
        }
    }
}

private struct SettingsButton: View {
    let title: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Capsule().fill(prominent ? SettingsStyle.accent : Color.white.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .focusable(false)
    }
}
