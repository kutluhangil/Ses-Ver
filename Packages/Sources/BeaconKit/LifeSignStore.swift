import Foundation

/// Son "Buradayım" dokunuşunu ve lifeAge kodunu hesaplayan yönetici (docs/contracts/signal-v1.md §4.1).
public final class LifeSignStore: @unchecked Sendable {
    public static let shared = LifeSignStore()

    private let lock = NSLock()
    private var _lastTouchTime: Date?

    public init(lastTouchTime: Date? = nil) {
        self._lastTouchTime = lastTouchTime
    }

    public func registerTouch(at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        _lastTouchTime = date
    }

    public var lastTouchTime: Date? {
        lock.lock()
        defer { lock.unlock() }
        return _lastTouchTime
    }

    /// Son dokunuştan geçen süreye göre lifeAge indeksini döner (0..15).
    public func currentLifeAge(at now: Date = Date()) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard let last = _lastTouchTime else { return 15 } // 15: bilinmiyor
        let deltaMinutes = now.timeIntervalSince(last) / 60.0

        if deltaMinutes < 0 { return 15 }
        switch deltaMinutes {
        case ..<1.0: return 0
        case ..<2.0: return 1
        case ..<5.0: return 2
        case ..<10.0: return 3
        case ..<20.0: return 4
        case ..<30.0: return 5
        case ..<60.0: return 6
        case ..<(2.0 * 60.0): return 7
        case ..<(4.0 * 60.0): return 8
        case ..<(8.0 * 60.0): return 9
        case ..<(12.0 * 60.0): return 10
        case ..<(24.0 * 60.0): return 11
        case ..<(36.0 * 60.0): return 12
        case ..<(48.0 * 60.0): return 13
        default: return 14
        }
    }
}
