import Foundation
import CoreAudio

public struct AudioDeviceService: Sendable {
    public static func listOutputDevices() -> [String] {
        var result = ["System Default"]
        result.append(contentsOf: enumerateDevices(scope: kAudioDevicePropertyScopeOutput))
        return result
    }

    public static func listInputDevices() -> [String] {
        var result = ["System Default"]
        result.append(contentsOf: enumerateDevices(scope: kAudioDevicePropertyScopeInput))
        return result
    }

    private static func enumerateDevices(scope: AudioObjectPropertyScope) -> [String] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr, dataSize > 0 else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        ) == noErr else {
            return []
        }

        var names: [String] = []
        for deviceID in deviceIDs {
            if hasStreams(deviceID: deviceID, scope: scope),
               let name = deviceName(deviceID: deviceID),
               !name.isEmpty,
               !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    private static func hasStreams(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size)
        return status == noErr && size > 0
    }

    private static func deviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard status == noErr, let cfName else { return nil }
        return cfName.takeUnretainedValue() as String
    }
}
