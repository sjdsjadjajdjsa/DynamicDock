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

            Section("Showing the dock") {
                Picker("Reveal from", selection: Binding(
                    get: { settings.fullWidthTrigger },
                    set: { settings.fullWidthTrigger = $0 }
                )) {
                    Text("Centre of the bottom edge").tag(false)
                    Text("Entire bottom edge").tag(true)
                }

                delaySlider(
                    "Reveal delay",
                    value: Binding(get: { settings.revealDelay }, set: { settings.revealDelay = $0 }),
                    range: AppSettings.revealDelayRange
                )

                delaySlider(
                    "Hide delay",
                    value: Binding(get: { settings.hideDelay }, set: { settings.hideDelay = $0 }),
                    range: AppSettings.hideDelayRange
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 290)
        .onAppear { settings.refreshLaunchAtLogin() }
    }

    private func delaySlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range)
                    .frame(width: 180)
                Text(String(format: "%.2f s", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}
