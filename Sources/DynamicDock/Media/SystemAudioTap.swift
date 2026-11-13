import AudioToolbox
import CoreAudio
import Foundation

/// Listens to everything the Mac is playing through a Core Audio tap and
/// feeds it to an `AudioSpectrum`. macOS asks the user for permission to
/// record system audio the first time; without it the tap delivers silence.
@available(macOS 14.2, *)
final class SystemAudioTap {
    struct Failure: Error, CustomStringConvertible {
        let step: String
        let status: OSStatus
        var description: String { "\(step) failed (\(status))" }
    }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "com.dynamicdock.audiotap", qos: .userInteractive)

    func start(feeding spectrum: AudioSpectrum) throws {
        do {
            try startTap(feeding: spectrum)
        } catch {
            stop()
            throw error
        }
    }

    private func startTap(feeding spectrum: AudioSpectrum) throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "Dynamic Dock Visualizer"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        try check(AudioHardwareCreateProcessTap(description, &tapID), "Creating the audio tap")

        var format = AudioStreamBasicDescription()
        try read(tapID, kAudioTapPropertyFormat, into: &format, "Reading the tap format")
        if format.mSampleRate > 0 { spectrum.configure(sampleRate: format.mSampleRate) }

        var outputDevice = AudioObjectID(kAudioObjectUnknown)
        try read(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice,
                 into: &outputDevice, "Finding the output device")
        var outputUID: Unmanaged<CFString>?
        try read(outputDevice, kAudioDevicePropertyDeviceUID, into: &outputUID, "Reading the output device")
        guard let uid = outputUID?.takeRetainedValue() as String? else {
            throw Failure(step: "Reading the output device", status: -1)
        }

        // A private aggregate device is what turns the tap into an input stream.
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Dynamic Dock Visualizer",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: uid]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &deviceID), "Creating the tap device")

        try check(
            AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { _, input, _, _, _ in
                spectrum.process(input)
            },
            "Attaching to the tap device"
        )
        try check(AudioDeviceStart(deviceID, procID), "Starting the tap device")
    }

    func stop() {
        if deviceID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(deviceID, procID)
                AudioDeviceDestroyIOProcID(deviceID, procID)
            }
            AudioHardwareDestroyAggregateDevice(deviceID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        procID = nil
        deviceID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    deinit { stop() }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw Failure(step: step, status: status) }
    }

    private func read<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                         into value: inout T, _ step: String) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { bytes in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!)
        }
        try check(status, step)
    }
}
