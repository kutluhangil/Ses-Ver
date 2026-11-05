import Foundation
import Accelerate
import BeaconKit

public struct TrackedBeacon: Sendable, Identifiable {
    public let id: Int
    public let firstSeen: Date
    public let lastSeen: Date
    public let lastSNR: Float
    public let payload: PayloadV1
    public let frameCount: Int
    public let isVerifiedTwoFrames: Bool

    public init(
        id: Int,
        firstSeen: Date,
        lastSeen: Date,
        lastSNR: Float,
        payload: PayloadV1,
        frameCount: Int,
        isVerifiedTwoFrames: Bool
    ) {
        self.id = id
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.lastSNR = lastSNR
        self.payload = payload
        self.frameCount = frameCount
        self.isVerifiedTwoFrames = isVerifiedTwoFrames
    }
}

/// Çoklu işaret takipçisi ve iki çerçeve doğrulama yöneticisi (BLUEPRINT §3.4.1).
public final class BeaconTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var tracked: [Int: TrackedBeacon] = [:]

    public init() {}

    /// Yeni çözülen bir çerçeveyi kaydeder ve iki çerçeve kuralını denetler.
    @discardableResult
    public func registerFrame(payload: PayloadV1, snr: Float, at date: Date = Date()) -> TrackedBeacon {
        lock.lock()
        defer { lock.unlock() }

        if let existing = tracked[payload.id] {
            let updated = TrackedBeacon(
                id: payload.id,
                firstSeen: existing.firstSeen,
                lastSeen: date,
                lastSNR: snr,
                payload: payload,
                frameCount: existing.frameCount + 1,
                isVerifiedTwoFrames: true // İkinci çerçeve görüldü!
            )
            tracked[payload.id] = updated
            return updated
        } else {
            let fresh = TrackedBeacon(
                id: payload.id,
                firstSeen: date,
                lastSeen: date,
                lastSNR: snr,
                payload: payload,
                frameCount: 1,
                isVerifiedTwoFrames: false // Tek çerçeve: henüz doğrulanmadı
            )
            tracked[payload.id] = fresh
            return fresh
        }
    }

    public var allBeacons: [TrackedBeacon] {
        lock.lock()
        defer { lock.unlock() }
        return Array(tracked.values).sorted(by: { $0.lastSeen > $1.lastSeen })
    }

    public var verifiedBeacons: [TrackedBeacon] {
        lock.lock()
        defer { lock.unlock() }
        return tracked.values.filter { $0.isVerifiedTwoFrames }.sorted(by: { $0.lastSNR > $1.lastSNR })
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        tracked.removeAll()
    }
}

public enum FrameDecoder: Sendable {
    /// 10 sembollük CSS çıktısını ve RS(10,6) GF(16) kodunu çözer.
    public static func decode(shifts: [Int], tMax: Int = 1) -> (ok: Bool, payload: PayloadV1?) {
        guard shifts.count == 10 else { return (false, nil) }
        let nibbles = shifts.map { GrayCode.encode($0) }
        let (ok, corrected, _) = RS16.decode(nibbles, tMax: tMax)
        guard ok else { return (false, nil) }
        let payload = PayloadV1.fromNibbles(corrected)
        return (true, payload)
    }
}
