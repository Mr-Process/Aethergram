import Foundation
#if os(macOS)
import AppKit
#endif

/// Estimates approximate Telegram account registration date from numeric Peer ID,
/// mirroring Materialgram's `birthDateEnabled` (`advanced/materialgram_registration`) feature.
public enum ProfileMetadataEstimator {
    private static let milestones: [(id: Int64, timestamp: TimeInterval)] = [
        (100_000_000, 1_383_264_000),      // Nov 2013
        (200_000_000, 1_433_116_800),      // Jun 2015
        (400_000_000, 1_501_545_600),      // Aug 2017
        (700_000_000, 1_546_300_800),      // Jan 2019
        (1_000_000_000, 1_577_836_800),    // Jan 2020
        (1_500_000_000, 1_609_459_200),    // Jan 2021
        (2_000_000_000, 1_640_995_200),    // Jan 2022
        (5_000_000_000, 1_656_633_600),    // Jul 2022
        (6_000_000_000, 1_685_577_600),    // Jun 2023
        (7_000_000_000, 1_714_521_600),    // May 2024
        (8_000_000_000, 1_746_057_600),    // May 2025
        (9_000_000_000, 1_777_593_600),    // May 2026
    ]

    public static func estimatedRegistrationDate(forPeerId peerIdString: String) -> String? {
        guard let rawId = Int64(peerIdString), rawId > 0 else { return nil }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM yyyy"

        if let first = milestones.first, rawId <= first.id {
            return "~\(formatter.string(from: Date(timeIntervalSince1970: first.timestamp)))"
        }
        if let last = milestones.last, rawId >= last.id {
            return "~\(formatter.string(from: Date(timeIntervalSince1970: last.timestamp)))+"
        }
        for i in 0..<(milestones.count - 1) {
            let low = milestones[i]
            let high = milestones[i + 1]
            if rawId >= low.id && rawId <= high.id {
                let ratio = Double(rawId - low.id) / Double(high.id - low.id)
                let ts = low.timestamp + ratio * (high.timestamp - low.timestamp)
                return "~\(formatter.string(from: Date(timeIntervalSince1970: ts)))"
            }
        }
        return nil
    }

    /// Formats a username as `@example` matching Materialgram's "Copy usernames as @example" feature.
    public static func formattedHandle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed.hasPrefix("@") ? trimmed : "@\(trimmed)"
    }

    public static func copyToClipboard(_ value: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}
