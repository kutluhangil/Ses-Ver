import Foundation
import Accelerate
import BeaconKit

/// Kurtarıcı tarafı akustik sinyal algılama ve çözme hattı (docs/contracts/signal-v1.md §7).
public final class BeaconTracker: Sendable {
    public struct TrackedBeacon: Sendable, Identifiable {
        public let id: Int
        public let firstSeen: Date
        public let lastSeen: Date
        public let lastSNR: Float
        public let payload: PayloadV1
        public let verifiedTwoFrames: Bool
    }

    public init() {}
}

public enum FrameDecoder: Sendable {
    /// 10 sembollük CSS çıktısını ve RS(10,6) GF(16) kodunu çözer.
    public static func decode(shifts: [Int], tMax: Int = 1) -> (ok: Bool, payload: PayloadV1?) {
        let nibbles = shifts.map { GrayCode.encode($0) }
        let (ok, corrected, _) = RS16.decode(nibbles, tMax: tMax)
        guard ok else { return (false, nil) }
        let payload = PayloadV1.fromNibbles(corrected)
        return (true, payload)
    }
}
