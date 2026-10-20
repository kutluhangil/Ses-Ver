import SwiftUI
import UIKit

/// Spike (c): `UIBackgroundModes: audio` ile ekran kapalı, 72 saat (veya sistem öldürene kadar)
/// periyodik duyulabilir işaret + (playAndRecord varyantında) mikrofon. Sistem uygulamayı öldürüyor mu?
///
/// Kanıt zinciri: TSV log (60 s kalp atışı + `framesEmitted`), `previous_run_unclean` olayı,
/// MetricKit `backgroundExitData`, sysdiagnose (runningboardd / audiomxd satırları), harici ses kaydı.
@main
struct SpikeCApp: App {
    @UIApplicationDelegateAdaptor(SpikeCDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike C · 72 sa arka plan") {
                Section("Prosedür") {
                    Text("1) Varyant + aralık seç, Başlat. 2) Kalp atışı log'da görünsün. 3) Ekranı kilitle, cihazı ölçüm düzeneğine koy. 4) Kesinti matrisini uygulama (plan §c). 5) Bitişte log + MetricKit klasörünü + sysdiagnose'u topla.")
                        .font(.footnote)
                    ShareLink("MetricKit JSON klasörü", item: FileManager.default
                        .urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("metrickit", isDirectory: true))
                }
            }
        }
    }
}

final class SpikeCDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        SystemObservers.install()
        RunMarker.markLaunch()
        Heartbeat.start(every: 60)
        return true
    }
}
