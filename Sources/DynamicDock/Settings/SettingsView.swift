import SwiftUI

struct SettingsView: View {
    let settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Position") {
                Picker("Screen edge", selection: Binding(
                    get: { settings.edge },
                    set: { settings.edge = $0 }
                )) {
                    Text("Left").tag(DockEdge.left)
                    Text("Bottom").tag(DockEdge.bottom)
                    Text("Right").tag(DockEdge.right)
                }
                .pickerStyle(.segmented)

                // 0 is the left end of the bottom edge, or the bottom of a side edge.
                slider(
                    settings.edge.isVertical ? "Height on screen" : "Position along edge",
                    value: Binding(get: { settings.position }, set: { settings.position = $0 }),
                    range: 0...1,
                    label: String(format: "%.0f%%", settings.position * 100)
                )

                slider(
                    "Distance from edge",
                    value: Binding(get: { settings.edgeMargin }, set: { settings.edgeMargin = $0.rounded() }),
                    range: AppSettings.edgeMarginRange,
                    label: String(format: "%.0f pt", settings.edgeMargin)
                )
            }

            Section("Showing the dock") {
                Picker("Reveal from", selection: Binding(
                    get: { settings.fullWidthTrigger },
                    set: { settings.fullWidthTrigger = $0 }
                )) {
                    Text("The edge next to the dock").tag(false)
                    Text("The entire edge").tag(true)
                }

                slider(
                    "Reveal delay",
                    value: Binding(get: { settings.revealDelay }, set: { settings.revealDelay = $0 }),
                    range: AppSettings.revealDelayRange,
                    label: String(format: "%.2f s", settings.revealDelay)
                )

                slider(
                    "Hide delay",
                    value: Binding(get: { settings.hideDelay }, set: { settings.hideDelay = $0 }),
                    range: AppSettings.hideDelayRange,
                    label: String(format: "%.2f s", settings.hideDelay)
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 470)
        .onAppear { settings.refreshLaunchAtLogin() }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, label: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range)
                    .frame(width: 180)
                Text(label)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}
