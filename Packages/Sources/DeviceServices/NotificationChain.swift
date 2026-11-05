import Foundation
import UserNotifications

/// Katman 2: Kritik bildirim zinciri (BLUEPRINT §3.2 Katman 2).
/// Uygulama askıya alınsa veya öldürülse bile periyodik olarak yerel bildirimlerle işaret çalar.
public final class NotificationChain: @unchecked Sendable {
    public static let shared = NotificationChain()

    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    private init() {}

    public func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .criticalAlert]
        return try await center.requestAuthorization(options: options)
    }

    /// 64 yerel bildirim zincirini planlar.
    public func scheduleChain(isCritical: Bool = false) async {
        center.removeAllPendingNotificationRequests()

        var accumulatedDelay: TimeInterval = 0

        // Plan: İlk 2 saat 5 dk'da bir (24 adet), sonraki 10 saat 15 dk'da bir (40 adet) = 64 adet (iOS sınırı)
        for i in 1...64 {
            let stepDelay: TimeInterval = i <= 24 ? 300 : 900
            accumulatedDelay += stepDelay

            let content = UNMutableNotificationContent()
            content.title = "Ses Ver: Enkaz Altı Sinyali"
            content.body = "İşaret çalınıyor. Durumunuzu bildirmek için dokunun."

            if isCritical {
                content.sound = UNNotificationSound.criticalSoundNamed(
                    UNNotificationSoundName("sv_chirp_25s.wav"),
                    withAudioVolume: 1.0
                )
            } else {
                content.sound = UNNotificationSound.default
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: accumulatedDelay, repeats: false)
            let request = UNNotificationRequest(identifier: "sesver.chain.\(i)", content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    public func cancelChain() {
        center.removeAllPendingNotificationRequests()
    }
}
