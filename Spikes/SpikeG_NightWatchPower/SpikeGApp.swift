import CoreMotion
import SwiftUI
import UIKit

/// Spike (g): Gece Nöbeti güç tüketimi. Ön planda, OLED siyah ekran + soluk kehribar saat,
/// `isIdleTimerDisabled = true` (yalnızca şarjdayken veya "tezgâh modu"nda), Core Motion 50 Hz STA/LTA.
///
/// Bu spike tetikte işaret ÇALMAZ; yalnızca `sta_lta_trigger` loglar (eşik kalibrasyonu F3-6).
/// Güç: (1) şarjdan ayrık tezgâh modunda %/saat, (2) Xcode Instruments "Power Profiler" izi.
@main
struct SpikeGApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
        }
    }

    var body: some Scene {
        WindowGroup { NightWatchRoot() }
    }
}

/// STA/LTA dedektörü. Yalnızca kendi seri `OperationQueue`'sunda çalışır.
final class StaLta: @unchecked Sendable {
    private var sta = 0.0
    private var lta = 1e-4
    private var samples = 0
    private var triggeredUntil = 0
    private var gravity = (x: 0.0, y: 0.0, z: 0.0)
    let staN = 25.0     // 0,5 s @ 50 Hz
    let ltaN = 1_500.0  // 30 s @ 50 Hz
    let threshold = 4.0

    /// Tetik varsa (oran, büyüklük) döndürür.
    func push(x: Double, y: Double, z: Double) -> (Double, Double)? {
        // Yerçekimini yavaş alçak geçiren filtreyle çıkar.
        let a = 0.02
        gravity = (gravity.x + a * (x - gravity.x), gravity.y + a * (y - gravity.y), gravity.z + a * (z - gravity.z))
        let dx = x - gravity.x, dy = y - gravity.y, dz = z - gravity.z
        let e = dx * dx + dy * dy + dz * dz
        sta += (e - sta) / staN
        lta += (e - lta) / ltaN
        samples += 1
        guard samples > Int(ltaN) else { return nil }       // LTA ısınması
        let ratio = sta / max(lta, 1e-6)
        if ratio > threshold && samples > triggeredUntil {
            triggeredUntil = samples + 500                  // 10 s ölü süre
            return (ratio, sqrt(e))
        }
        return nil
    }
}

@MainActor
final class NightWatch {
    static let shared = NightWatch()
    private let motion = CMMotionManager()
    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .utility
        return q
    }()
    private let detector = StaLta()
    private(set) var active = false
    var benchMode = false   // şarjsız güç ölçümü için

    func start() {
        guard motion.isAccelerometerAvailable else {
            SpikeLog.shared.log("nightwatch_no_accelerometer"); return
        }
        active = true
        updateIdleTimer()
        motion.accelerometerUpdateInterval = 1.0 / 50.0
        let det = detector
        motion.startAccelerometerUpdates(to: queue) { data, _ in
            guard let a = data?.acceleration else { return }
            if let (ratio, mag) = det.push(x: a.x, y: a.y, z: a.z) {
                SpikeLog.shared.log("sta_lta_trigger", [("ratio", String(format: "%.1f", ratio)),
                                                        ("magG", String(format: "%.3f", mag))])
            }
        }
        SpikeLog.shared.log("nightwatch_started", [("bench", "\(benchMode)")] + SystemObservers.snapshot())
    }

    func stop() {
        motion.stopAccelerometerUpdates()
        active = false
        UIApplication.shared.isIdleTimerDisabled = false
        SpikeLog.shared.log("nightwatch_stopped", SystemObservers.snapshot())
    }

    /// Ürün kuralı: ekran yalnızca şarjdayken açık tutulur. Tezgâh modu ölçüm içindir.
    func updateIdleTimer() {
        let s = UIDevice.current.batteryState
        let charging = s == .charging || s == .full
        UIApplication.shared.isIdleTimerDisabled = active && (charging || benchMode)
        SpikeLog.shared.log("idle_timer", [("disabled", "\(UIApplication.shared.isIdleTimerDisabled)"),
                                          ("charging", "\(charging)"), ("bench", "\(benchMode)")])
    }
}

struct NightWatchRoot: View {
    @State private var running = false
    @State private var bench = false

    var body: some View {
        if running {
            // OLED siyah zemin, soluk kehribar saat. Dokunma = çıkış (spike).
            ZStack {
                Color.black.ignoresSafeArea()
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    Text(ctx.date, style: .time)
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.33, blue: 0.0).opacity(0.35))
                }
            }
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .onTapGesture(count: 3) {
                NightWatch.shared.stop()
                running = false
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)) { _ in
                NightWatch.shared.updateIdleTimer()
            }
        } else {
            SpikeHarnessView(title: "Spike G · Gece Nöbeti güç", showEngineControls: false) {
                Section("Gece Nöbeti") {
                    Toggle("Tezgâh modu (şarjsız ölçüm için ekranı açık tut)", isOn: $bench)
                    Button("Başlat (çıkış: 3 kez dokun)") {
                        NightWatch.shared.benchMode = bench
                        NightWatch.shared.start()
                        Heartbeat.start(every: 300)
                        running = true
                    }
                    .buttonStyle(.borderedProminent)
                    Text("Ekran parlaklığını elle en düşüğe alın; True Tone/Otomatik Parlaklık durumu sonuç dosyasına yazılır.")
                        .font(.footnote)
                }
            }
        }
    }
}
