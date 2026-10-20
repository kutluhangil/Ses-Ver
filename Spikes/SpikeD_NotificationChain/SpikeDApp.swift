import BackgroundTasks
import SwiftUI
import UserNotifications

/// Spike (d): 64 yerel bildirim zinciri + `Library/Sounds` içine çalışma anında yazılan işaret sesi.
/// Kritik uyarı varyantı yalnızca Apple entitlement'ı onaylandıktan sonra (F0-8) imzalanabilir.
@main
struct SpikeDApp: App {
    @UIApplicationDelegateAdaptor(SpikeDDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike D · Bildirim zinciri", showEngineControls: true) {
                NotificationChainSection()
            }
        }
    }
}

final class SpikeDDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        SystemObservers.install()
        RunMarker.markLaunch()
        UNUserNotificationCenter.current().delegate = self
        ChainRefresh.register()
        Task { await NotificationChain.logDeliveredAndPending(context: "launch") }
        return true
    }

    // Ön plandayken gelen bildirimi de sesli göster (zinciri ön planda da ölçebilmek için).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        let date = notification.date
        await MainActor.run {
            SpikeLog.shared.log("notification_will_present", [("id", id), ("fireDate", "\(date)")])
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        await MainActor.run {
            SpikeLog.shared.log("notification_opened", [("id", id)])
        }
        // Ürün davranışı: uygulama her canlandığında zincir yeniden doldurulur (BLUEPRINT §3.2).
        await NotificationChain.refill(reason: "notificationOpened")
    }
}

enum ChainSound: String, CaseIterable, Sendable {
    case library25 = "Library/Sounds 25 s"
    case library31 = "Library/Sounds 31 s (sınır testi)"
    case bundle25 = "Paket 25 s"
    case systemDefault = "Varsayılan"

    var fileName: String? {
        switch self {
        case .library25: return "sv_chain_lib_25s.wav"
        case .library31: return "sv_chain_lib_31s.wav"
        case .bundle25: return "sv_chirp_25s.wav"
        case .systemDefault: return nil
        }
    }
}

enum ChainLevel: String, CaseIterable, Sendable {
    case active = "normal (active)"
    case timeSensitive = "timeSensitive"
    case critical = "critical (entitlement gerekir)"
}

enum ChainPlan: String, CaseIterable, Sendable {
    /// Ürün planı: 24 × 5 dk + 40 × 15 dk = 12 saat (BLUEPRINT §3.2).
    case product = "Ürün: 24×5 dk + 40×15 dk"
    /// K2 (24 sa) boşluğu adayı: 12×5 dk + 12×15 dk + 40×30 dk = 24 saat (ADR-0003 olumsuz sonuç).
    case product24 = "24 sa: 12×5 + 12×15 + 40×30 dk"
    /// Hızlı doğrulama: 64 × 1 dk.
    case fast = "Hızlı: 64×1 dk"
    /// 64 sınırı: 70 istek eklenir, kaçının beklediği sayılır.
    case overflow = "Taşma: 70×10 dk"

    var offsets: [TimeInterval] {
        switch self {
        case .product: return (1...24).map { Double($0) * 300 } + (1...40).map { 7_200 + Double($0) * 900 }
        case .product24:
            return (1...12).map { Double($0) * 300 }
                + (1...12).map { 3_600 + Double($0) * 900 }
                + (1...40).map { 14_400 + Double($0) * 1_800 }
        case .fast: return (1...64).map { Double($0) * 60 }
        case .overflow: return (1...70).map { Double($0) * 600 }
        }
    }
}

@MainActor
enum NotificationChain {
    static var sound: ChainSound = .library25
    static var level: ChainLevel = .active
    static var plan: ChainPlan = .fast

    static func requestAuthorization(critical: Bool) async {
        var opts: UNAuthorizationOptions = [.alert, .sound, .badge]
        if critical { opts.insert(.criticalAlert) }
        do {
            let ok = try await UNUserNotificationCenter.current().requestAuthorization(options: opts)
            let s = await UNUserNotificationCenter.current().notificationSettings()
            SpikeLog.shared.log("notif_auth", [
                ("granted", "\(ok)"), ("critical", "\(s.criticalAlertSetting.rawValue)"),
                ("timeSensitive", "\(s.timeSensitiveSetting.rawValue)"), ("sound", "\(s.soundSetting.rawValue)"),
            ])
        } catch {
            SpikeLog.shared.log("notif_auth_failed", [("error", "\(error)")])
        }
    }

    static func writeSounds() {
        do {
            let a = try ChirpWaveform.writeLibrarySound(named: "sv_chain_lib_25s.wav", totalSeconds: 25)
            let b = try ChirpWaveform.writeLibrarySound(named: "sv_chain_lib_31s.wav", totalSeconds: 31)
            SpikeLog.shared.log("sounds_written", [("a", a.path), ("b", b.path)])
        } catch {
            SpikeLog.shared.log("sounds_write_failed", [("error", "\(error)")])
        }
    }

    static func makeSound() -> UNNotificationSound {
        guard let name = sound.fileName.map(UNNotificationSoundName.init(rawValue:)) else {
            return level == .critical ? .defaultCritical : .default
        }
        return level == .critical
            ? .criticalSoundNamed(name, withAudioVolume: 1.0)
            : UNNotificationSound(named: name)
    }

    static func schedule() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date()
        var added = 0
        for (i, offset) in plan.offsets.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Ses Ver spike D"
            content.body = "Zincir #\(i + 1) · planlanan \(Int(offset)) s"
            content.sound = makeSound()
            switch level {
            case .active: content.interruptionLevel = .active
            case .timeSensitive: content.interruptionLevel = .timeSensitive
            case .critical: content.interruptionLevel = .critical
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: offset, repeats: false)
            let req = UNNotificationRequest(identifier: String(format: "chain-%03d", i + 1), content: content, trigger: trigger)
            do { try await center.add(req); added += 1 } catch {
                SpikeLog.shared.log("notif_add_failed", [("index", "\(i + 1)"), ("error", "\(error)")])
            }
        }
        SpikeLog.shared.log("chain_scheduled", [
            ("plan", plan.rawValue), ("sound", sound.rawValue), ("level", level.rawValue),
            ("added", "\(added)"), ("firstFire", "\(now.addingTimeInterval(plan.offsets.first ?? 0))"),
            ("lastFire", "\(now.addingTimeInterval(plan.offsets.last ?? 0))"),
        ])
        await logDeliveredAndPending(context: "afterSchedule")
    }

    /// Katman 1 çalışırken en yakın bildirimi ileri kaydırma (BLUEPRINT §3.2 son madde).
    static func shiftNearest(by seconds: TimeInterval) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard let nearest = pending.min(by: { nextFire($0) < nextFire($1) }) else { return }
        center.removePendingNotificationRequests(withIdentifiers: [nearest.identifier])
        let fire = nextFire(nearest).timeIntervalSinceNow + seconds
        let req = UNNotificationRequest(
            identifier: nearest.identifier, content: nearest.content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, fire), repeats: false))
        do { try await center.add(req) } catch {
            SpikeLog.shared.log("notif_shift_failed", [("error", "\(error)")])
        }
        SpikeLog.shared.log("chain_shift", [("id", nearest.identifier), ("newFireIn", String(format: "%.0f", fire))])
    }

    static func refill(reason: String) async {
        SpikeLog.shared.log("chain_refill", [("reason", reason)])
        await schedule()
    }

    static func logDeliveredAndPending(context: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        let pendingSummary = pending.map { "\($0.identifier)@\(Int(nextFire($0).timeIntervalSinceNow))s" }
            .sorted().prefix(80).joined(separator: ",")
        let deliveredSummary = delivered.map { "\($0.request.identifier)@\(Int($0.date.timeIntervalSince1970))" }
            .sorted().joined(separator: ",")
        SpikeLog.shared.log("chain_status", [
            ("context", context), ("pending", "\(pending.count)"), ("delivered", "\(delivered.count)"),
            ("pendingList", pendingSummary), ("deliveredList", deliveredSummary),
        ])
    }

    private static func nextFire(_ r: UNNotificationRequest) -> Date {
        (r.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }
}

struct NotificationChainSection: View {
    @State private var sound: ChainSound = NotificationChain.sound
    @State private var level: ChainLevel = NotificationChain.level
    @State private var plan: ChainPlan = NotificationChain.plan

    var body: some View {
        Section("Bildirim zinciri") {
            Button("İzin iste (normal)") { Task { await NotificationChain.requestAuthorization(critical: false) } }
            Button("İzin iste (+ kritik)") { Task { await NotificationChain.requestAuthorization(critical: true) } }
            Button("Library/Sounds dosyalarını yaz (25 s, 31 s)") { NotificationChain.writeSounds() }
            Picker("Ses", selection: $sound) { ForEach(ChainSound.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Düzey", selection: $level) { ForEach(ChainLevel.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Plan", selection: $plan) { ForEach(ChainPlan.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Button("Zinciri planla") {
                NotificationChain.sound = sound
                NotificationChain.level = level
                NotificationChain.plan = plan
                Task { await NotificationChain.schedule() }
            }
            .buttonStyle(.borderedProminent)
            Button("En yakını 5 dk ileri kaydır") { Task { await NotificationChain.shiftNearest(by: 300) } }
            Button("Bekleyen/teslim edilenleri logla") { Task { await NotificationChain.logDeliveredAndPending(context: "manual") } }
            Button("Tümünü iptal et", role: .destructive) {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                SpikeLog.shared.log("chain_cancelled")
            }
        }
    }
}

/// K2 boşluğu ölçümü: sistem uygulamayı arka planda ne sıklıkla canlandırıyor? Her canlanmada zincir
/// yeniden doldurulur ve `bg_refresh_run` loglanır. [Kesin değil] Kullanıcı uygulamayı zorla kapattıysa
/// arka plan yenilemesi genelde çalışmaz; spike (d) bunu ayrıca ölçer. Zamanlama tamamen sistemin elindedir.
enum ChainRefresh {
    static let id = "sesver.spike.d.refresh"

    @MainActor
    static func register() {
        let ok = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { task in
            nonisolated(unsafe) let t = task
            MainActor.assumeIsolated {
                SpikeLog.shared.log("bg_refresh_run", SystemObservers.snapshot())
                schedule()
                Task { @MainActor in
                    await NotificationChain.refill(reason: "bgAppRefresh")
                    t.setTaskCompleted(success: true)
                }
            }
        }
        SpikeLog.shared.log("bg_refresh_registered", [("ok", "\(ok)")])
        schedule()
    }

    @MainActor
    static func schedule() {
        let req = BGAppRefreshTaskRequest(identifier: id)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do { try BGTaskScheduler.shared.submit(req) } catch {
            SpikeLog.shared.log("bg_refresh_submit_failed", [("error", "\(error)")])
        }
    }
}
