import AVFoundation
import MetricKit
import UIKit

/// Yaşam döngüsü, kilit (korumalı veri), termal, Düşük Güç Modu, bellek ve pil olaylarını loglar.
/// Kesinti senaryoları (BLUEPRINT §5.2 ios-platform) bu olaylarla kanıtlanır.
@MainActor
enum SystemObservers {
    private static var tokens: [NSObjectProtocol] = []
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        let nc = NotificationCenter.default
        func on(_ name: Notification.Name, _ event: String, _ extra: @escaping @MainActor () -> [(String, String)] = { [] }) {
            tokens.append(nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    SpikeLog.shared.log(event, extra() + snapshot())
                    if event == "did_enter_background" { SpikeLog.shared.flush() }
                }
            })
        }
        on(UIApplication.didFinishLaunchingNotification, "did_finish_launching")
        on(UIApplication.didBecomeActiveNotification, "did_become_active")
        on(UIApplication.willResignActiveNotification, "will_resign_active")
        on(UIApplication.didEnterBackgroundNotification, "did_enter_background")
        on(UIApplication.willEnterForegroundNotification, "will_enter_foreground")
        on(UIApplication.willTerminateNotification, "will_terminate")
        on(UIApplication.didReceiveMemoryWarningNotification, "memory_warning")
        // Parola ayarlıysa: kilitlenince ~10 s sonra "unavailable", açılınca "available".
        on(UIApplication.protectedDataWillBecomeUnavailableNotification, "protected_data_will_be_unavailable")
        on(UIApplication.protectedDataDidBecomeAvailableNotification, "protected_data_available")
        on(ProcessInfo.thermalStateDidChangeNotification, "thermal_state_change")
        on(Notification.Name.NSProcessInfoPowerStateDidChange, "low_power_mode_change")
        on(UIDevice.batteryStateDidChangeNotification, "battery_state_change")
        MetricsSink.shared.start()
    }

    /// Her olaya eklenen durum özeti.
    static func snapshot() -> [(String, String)] {
        let app = UIApplication.shared
        let state: String
        switch app.applicationState {
        case .active: state = "active"
        case .inactive: state = "inactive"
        case .background: state = "background"
        @unknown default: state = "unknown"
        }
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "nominal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unknown"
        }
        let battery = UIDevice.current.batteryLevel
        let bstate: String
        switch UIDevice.current.batteryState {
        case .charging: bstate = "charging"
        case .full: bstate = "full"
        case .unplugged: bstate = "unplugged"
        default: bstate = "unknown"
        }
        return [
            ("appState", state),
            ("protectedData", "\(app.isProtectedDataAvailable)"),
            ("thermal", thermal),
            ("lowPower", "\(ProcessInfo.processInfo.isLowPowerModeEnabled)"),
            ("battery", battery < 0 ? "?" : String(format: "%.2f", battery)),
            ("batteryState", bstate),
            ("bgTimeRemaining", app.backgroundTimeRemaining > 1e9 ? "inf" : String(format: "%.0f", app.backgroundTimeRemaining)),
        ]
    }
}

/// Belirli aralıkla durum + ses çerçevesi sayacı yazar. Uygulama sonlandırılırsa son kalp atışı
/// `RunMarker` üzerinden bir sonraki açılışta raporlanır.
@MainActor
enum Heartbeat {
    private static var task: Task<Void, Never>?

    static func start(every seconds: Double = 60) {
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                beat()
                try? await Task.sleep(for: .seconds(seconds))
            }
        }
    }

    static func stop() { task?.cancel(); task = nil }

    static func beat() {
        let engine = ChirpEngine.shared
        let (peak, buffers) = engine.mic.takePeak()
        let up = engine.startedAt.map { Date().timeIntervalSince($0) / 3600 } ?? 0
        SpikeLog.shared.log("heartbeat", [
            ("engineRunning", "\(engine.isRunning)"),
            ("framesEmitted", "\(engine.framesEmitted)"),
            ("restarts", "\(engine.restartCount)"),
            ("beaconHours", String(format: "%.3f", up)),
            ("outputVolume", String(format: "%.2f", AVAudioSession.sharedInstance().outputVolume)),
            ("route", ChirpEngine.routeDescription()),
            ("micPeak", String(format: "%.4f", peak)),
            ("micBuffers", "\(buffers)"),
        ] + SystemObservers.snapshot())
        RunMarker.heartbeat()
    }
}

/// MetricKit yükleri (günlük metrikler ve tanılama: çökme, CPU/disk istisnası, uygulama çıkış
/// nedenleri) `Documents/metrickit/` altına JSON olarak yazılır. Arka planda sonlandırma nedenleri
/// (`MXAppExitMetric.backgroundExitData`: bellek baskısı, watchdog, CPU kaynak sınırı…) spike (c)'nin
/// birincil kanıtıdır. Yükler genelde 24 saatte bir gelir.
final class MetricsSink: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = MetricsSink()

    func start() { MXMetricManager.shared.add(self) }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads { save(p.jsonRepresentation(), kind: "metric") }
        if let exits = payloads.last?.applicationExitMetrics?.backgroundExitData {
            SpikeLog.shared.log("metrickit_background_exits", [
                ("normal", "\(exits.cumulativeNormalAppExitCount)"),
                ("memoryPressure", "\(exits.cumulativeMemoryPressureExitCount)"),
                ("memoryLimit", "\(exits.cumulativeMemoryResourceLimitExitCount)"),
                ("cpuLimit", "\(exits.cumulativeCPUResourceLimitExitCount)"),
                ("watchdog", "\(exits.cumulativeAppWatchdogExitCount)"),
                ("suspendedLockedFile", "\(exits.cumulativeSuspendedWithLockedFileExitCount)"),
                ("badAccess", "\(exits.cumulativeBadAccessExitCount)"),
                ("abnormal", "\(exits.cumulativeAbnormalExitCount)"),
                ("illegalInstruction", "\(exits.cumulativeIllegalInstructionExitCount)"),
                ("bgTaskTimeout", "\(exits.cumulativeBackgroundTaskAssertionTimeoutExitCount)"),
            ])
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads { save(p.jsonRepresentation(), kind: "diagnostic") }
        SpikeLog.shared.log("metrickit_diagnostics", [("count", "\(payloads.count)")])
    }

    private func save(_ data: Data, kind: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("metrickit", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = "\(kind)-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(4)).json"
        try? data.write(to: dir.appendingPathComponent(name))
    }
}
