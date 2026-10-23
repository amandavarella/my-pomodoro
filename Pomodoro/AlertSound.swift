import AVFoundation
import CoreAudio
import Foundation

/// Plays the interval-finished alert. When asked, it targets the built-in
/// MacBook speakers directly, ignoring whatever the system output is set to
/// (Multi-Output Device, BlackHole, headphones, and so on).
final class AlertSound {
    private static let soundsDirectory = URL(fileURLWithPath: "/System/Library/Sounds")

    private let player = AVQueuePlayer()

    /// The macOS alert sounds available on this Mac, such as Glass, Ping, and Hero.
    static let availableSounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(at: soundsDirectory, includingPropertiesForKeys: nil)) ?? []
        let names = files
            .filter { $0.pathExtension == "aiff" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return names.isEmpty ? ["Glass"] : names
    }()

    func play(settings: PomodoroSettings) {
        play(soundName: settings.soundName,
             volume: Float(settings.soundVolume),
             repeats: settings.soundRepeats,
             forceBuiltInSpeakers: settings.forceBuiltInSpeakers)
    }

    func play(soundName: String, volume: Float, repeats: Int, forceBuiltInSpeakers: Bool) {
        var url = Self.soundsDirectory.appendingPathComponent(soundName).appendingPathExtension("aiff")
        if !FileManager.default.fileExists(atPath: url.path) {
            url = Self.soundsDirectory.appendingPathComponent("Glass.aiff")
        }

        player.pause()
        player.removeAllItems()
        // nil means "follow the system output device".
        player.audioOutputDeviceUniqueID = forceBuiltInSpeakers ? AudioDevices.builtInSpeakers()?.uid : nil
        player.volume = volume
        for _ in 0..<max(1, repeats) {
            player.insert(AVPlayerItem(url: url), after: nil)
        }
        player.play()
    }

    /// Human-readable description of where the alert will play, for the settings panel.
    static func outputDescription(forceBuiltInSpeakers: Bool) -> String {
        guard forceBuiltInSpeakers else {
            return "Plays through the current system output."
        }
        if let speakers = AudioDevices.builtInSpeakers() {
            return "Plays through \(speakers.name)."
        }
        return "Built-in speakers not found, so it plays through the system output."
    }
}

/// Minimal Core Audio helpers for finding the built-in output device.
enum AudioDevices {
    struct Device {
        let id: AudioDeviceID
        let uid: String
        let name: String
    }

    /// The Mac's built-in speakers ("MacBook Pro Speakers"), if present.
    static func builtInSpeakers() -> Device? {
        for id in allDeviceIDs() where hasOutputStreams(id) && transportType(id) == kAudioDeviceTransportTypeBuiltIn {
            guard let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { continue }
            let name = stringProperty(id, kAudioObjectPropertyName) ?? "built-in speakers"
            return Device(id: id, uid: uid, name: name)
        }
        return nil
    }

    private static func propertyAddress(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = propertyAddress(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = propertyAddress(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func transportType(_ id: AudioDeviceID) -> UInt32 {
        var address = propertyAddress(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = propertyAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr,
              let string = value?.takeRetainedValue() else { return nil }
        return string as String
    }
}
