import Foundation

/// Çerçeve yayım zamanlaması ve pil koruma görev döngüsü yöneticisi (docs/contracts/signal-v1.md §6).
public struct ScheduleEngine: Sendable {
    public let startTime: Date

    public init(startTime: Date = Date()) {
        self.startTime = startTime
    }

    /// Verilen an ve pil seviyesine göre temel aralığı (saniye) döner.
    public func baseInterval(at now: Date = Date(), batteryPercent: Double = 100.0) -> Double {
        let elapsedHours = now.timeIntervalSince(startTime) / 3600.0
        let base: Double
        switch elapsedHours {
        case ..<6.0:
            base = 10.0
        case 6.0..<24.0:
            base = 20.0
        case 24.0..<72.0:
            base = 45.0
        default:
            base = 90.0
        }

        let batteryFactor = batteryPercent < 20.0 ? 2.0 : 1.0
        return base * batteryFactor
    }

    /// ±%15 rastgele sapma (jitter) eklenmiş bir sonraki çerçeve bekleme süresi.
    public func nextInterval(at now: Date = Date(), batteryPercent: Double = 100.0) -> Double {
        let base = baseInterval(at: now, batteryPercent: batteryPercent)
        let jitterFraction = Double.random(in: -0.15...0.15)
        let interval = base * (1.0 + jitterFraction)
        // Güvenlik alt sınırı: Ton / interval <= 0.12 => Ton=1.024s için interval >= 8.54s
        return max(8.6, interval)
    }
}
