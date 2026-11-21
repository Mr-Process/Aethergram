import Foundation
import AVFoundation
#if os(macOS)
import AppKit
#endif

/// Plays Materialgram notification chimes respecting volume and global mute settings.
@MainActor
public final class NotificationSoundService {
    public static let shared = NotificationSoundService()
    private var player: AVAudioPlayer?

    public init() {}

    public func shouldPlaySound(allowSound: Bool, volumePercent: Double) -> Bool {
        return allowSound && volumePercent > 0
    }

    public func playNotificationChime(allowSound: Bool, volumePercent: Double) {
        guard shouldPlaySound(allowSound: allowSound, volumePercent: volumePercent) else { return }
        let normalizedVolume = Float(max(0.0, min(1.0, volumePercent / 100.0)))

        let bundle = MD3Typography.resourceBundle
        if let customURL = bundle.url(forResource: "materialgram_notify", withExtension: "mp3", subdirectory: "Sounds")
            ?? bundle.url(forResource: "materialgram_notify", withExtension: "wav", subdirectory: "Sounds"),
           let audioPlayer = try? AVAudioPlayer(contentsOf: customURL) {
            audioPlayer.volume = normalizedVolume
            audioPlayer.play()
            self.player = audioPlayer
            return
        }

        #if os(macOS)
        if let sound = NSSound(named: NSSound.Name("Glass")) ?? NSSound(named: NSSound.Name("Pop")) {
            sound.volume = normalizedVolume
            sound.play()
        }
        #endif
    }
}
