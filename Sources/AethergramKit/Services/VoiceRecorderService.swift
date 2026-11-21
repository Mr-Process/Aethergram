import Foundation
import AVFoundation

/// Zero-delay voice message recorder capturing 256 kbps audio,
/// matching Materialgram's upgraded voice bitrate (32 -> 256 kbps) and zero start delay.
@MainActor
public final class VoiceRecorderService: ObservableObject {
    public static let targetBitrateBps: Int = 256_000
    public static let targetSampleRateHz: Double = 48_000

    @Published public var isRecording: Bool = false
    @Published public var elapsedSeconds: Int = 0
    @Published public var lastRecordingURL: URL? = nil
    @Published public var lastError: String? = nil

    private var recorder: AVAudioRecorder?
    private var startDate: Date?

    public init() {}

    public static func recorderSettings() -> [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: targetSampleRateHz,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: targetBitrateBps,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    public func startRecording() {
        guard !isRecording else { return }
        lastError = nil
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mg_voice_\(UUID().uuidString).m4a")
        do {
            let rec = try AVAudioRecorder(url: url, settings: Self.recorderSettings())
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            guard rec.record() else {
                lastError = "Could not start microphone recording. Check macOS Microphone permissions."
                return
            }
            recorder = rec
            lastRecordingURL = url
            startDate = Date()
            isRecording = true
            elapsedSeconds = 0
        } catch {
            lastError = "Voice recording failed: \(error.localizedDescription)"
        }
    }

    public func stopRecording() -> (url: URL, durationSeconds: Int)? {
        guard isRecording, let rec = recorder, let url = lastRecordingURL else { return nil }
        rec.stop()
        let duration = max(1, Int(Date().timeIntervalSince(startDate ?? Date())))
        recorder = nil
        isRecording = false
        elapsedSeconds = duration
        return (url, duration)
    }

    public func cancelRecording() {
        recorder?.stop()
        if let url = lastRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recorder = nil
        lastRecordingURL = nil
        isRecording = false
        elapsedSeconds = 0
    }
}
