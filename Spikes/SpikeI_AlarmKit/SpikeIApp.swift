import ActivityKit
import AlarmKit
import SwiftUI

/// Spike (i): AlarmKit (iOS 26+) Katman 2 için Critical Alerts'e alternatif/ek olabilir mi?
///
/// [Kesin] Alarm, gerekirse cihazın Odak'ını ve sessiz modunu aşar.
/// Kaynak: developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit
/// [Kesin] Apple (WWDC25-230): "Alarms … are not a replacement for other prominent notifications,
/// like critical alerts or time-sensitive notifications." → App Review riski yüksek (plan §i).
///
/// Ölçülenler: izin akışı, kaç alarm planlanabildiği (`maximumLimitReached`), özel ses (paket vs
/// Library/Sounds), çalma süresi/döngü, uygulama zorla kapatılmışken çalma, sessiz anahtar / Odak /
/// iOS 27 ayrı alarm ses düzeyi etkisi, kilit ekranında durdurma etkileşimi.
@main
struct SpikeIApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
            AlarmSpike.shared.observe()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike I · AlarmKit") {
                AlarmSection()
            }
        }
    }
}

struct SpikeAlarmMetadata: AlarmMetadata {
    var label: String
}

enum AlarmSound: String, CaseIterable, Sendable {
    case bundle25 = "Paket 25 s"
    case library25 = "Library/Sounds 25 s"
    case library31 = "Library/Sounds 31 s"
    case systemDefault = "Varsayılan"

    var alertSound: AlertConfiguration.AlertSound {
        switch self {
        case .bundle25: return .named("sv_chirp_25s.wav")
        case .library25: return .named("sv_alarm_lib_25s.wav")
        case .library31: return .named("sv_alarm_lib_31s.wav")
        case .systemDefault: return .default
        }
    }
}

@MainActor
final class AlarmSpike {
    static let shared = AlarmSpike()
    private var observeTask: Task<Void, Never>?

    func observe() {
        guard observeTask == nil else { return }
        observeTask = Task { @MainActor in
            for await alarms in AlarmManager.shared.alarmUpdates {
                let summary = alarms.map { "\($0.id.uuidString.prefix(6)):\(Self.stateName($0.state))" }
                    .joined(separator: ",")
                SpikeLog.shared.log("alarm_updates", [("count", "\(alarms.count)"), ("states", summary)]
                                    + SystemObservers.snapshot())
            }
        }
    }

    func requestAuthorization() async {
        do {
            let s = try await AlarmManager.shared.requestAuthorization()
            SpikeLog.shared.log("alarm_auth", [("state", "\(s)")])
        } catch {
            SpikeLog.shared.log("alarm_auth_failed", [("error", "\(error)")])
        }
    }

    func writeLibrarySounds() {
        do {
            try ChirpWaveform.writeLibrarySound(named: "sv_alarm_lib_25s.wav", totalSeconds: 25)
            try ChirpWaveform.writeLibrarySound(named: "sv_alarm_lib_31s.wav", totalSeconds: 31)
            SpikeLog.shared.log("alarm_sounds_written")
        } catch {
            SpikeLog.shared.log("alarm_sounds_write_failed", [("error", "\(error)")])
        }
    }

    private func attributes(_ label: String) -> AlarmAttributes<SpikeAlarmMetadata> {
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: "Ses Ver spike I")
        } else {
            alert = AlarmPresentation.Alert(
                title: "Ses Ver spike I",
                stopButton: AlarmButton(text: "Durdur", textColor: .white, systemImageName: "stop.fill"))
        }
        return AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: SpikeAlarmMetadata(label: label),
            tintColor: .orange)
    }

    /// `count` adet sabit tarihli alarm, `spacing` saniye arayla. Limit aşılırsa nerede durduğu loglanır.
    func scheduleSeries(count: Int, firstIn: TimeInterval, spacing: TimeInterval, sound: AlarmSound) async {
        var ok = 0
        for i in 0..<count {
            let date = Date().addingTimeInterval(firstIn + Double(i) * spacing)
            let config = AlarmManager.AlarmConfiguration<SpikeAlarmMetadata>.alarm(
                schedule: .fixed(date),
                attributes: attributes("seri-\(i + 1)"),
                sound: sound.alertSound)
            do {
                _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: config)
                ok += 1
            } catch {
                SpikeLog.shared.log("alarm_schedule_failed", [("index", "\(i + 1)"), ("error", "\(error)")])
                break
            }
        }
        let total = (try? AlarmManager.shared.alarms.count) ?? -1
        SpikeLog.shared.log("alarm_series_scheduled", [
            ("requested", "\(count)"), ("scheduled", "\(ok)"), ("totalNow", "\(total)"),
            ("firstIn", "\(firstIn)"), ("spacing", "\(spacing)"), ("sound", sound.rawValue),
        ])
    }

    func cancelAll() {
        let alarms = (try? AlarmManager.shared.alarms) ?? []
        for a in alarms { try? AlarmManager.shared.cancel(id: a.id) }
        SpikeLog.shared.log("alarm_cancel_all", [("count", "\(alarms.count)")])
    }

    static func stateName(_ s: Alarm.State) -> String {
        switch s {
        case .scheduled: return "scheduled"
        case .countdown: return "countdown"
        case .paused: return "paused"
        case .alerting: return "alerting"
        @unknown default: return "unknown"
        }
    }
}

struct AlarmSection: View {
    @State private var sound: AlarmSound = .bundle25

    var body: some View {
        Section("AlarmKit") {
            Button("İzin iste") { Task { await AlarmSpike.shared.requestAuthorization() } }
            Button("Library/Sounds dosyalarını yaz") { AlarmSpike.shared.writeLibrarySounds() }
            Picker("Ses", selection: $sound) { ForEach(AlarmSound.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Button("Tek alarm: 2 dk sonra") {
                Task { await AlarmSpike.shared.scheduleSeries(count: 1, firstIn: 120, spacing: 0, sound: sound) }
            }
            Button("Seri: 6 × 2 dk (hızlı)") {
                Task { await AlarmSpike.shared.scheduleSeries(count: 6, firstIn: 120, spacing: 120, sound: sound) }
            }
            Button("Limit testi: 500 × 30 dk (ilk 1 gün sonra)") {
                Task { await AlarmSpike.shared.scheduleSeries(count: 500, firstIn: 86_400, spacing: 1_800, sound: sound) }
            }
            Button("K2 boşluğu: 24 × 60 dk (12–36 sa arası)") {
                Task { await AlarmSpike.shared.scheduleSeries(count: 24, firstIn: 43_200, spacing: 3_600, sound: sound) }
            }
            Button("Tümünü iptal et", role: .destructive) { AlarmSpike.shared.cancelAll() }
        }
    }
}
