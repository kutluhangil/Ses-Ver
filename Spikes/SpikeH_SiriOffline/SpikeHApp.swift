import AppIntents
import Network
import SwiftUI

/// Spike (h): Siri ile başlatma, internetsiz (Uçak Modu, Wi-Fi/hücresel kapalı), TR ve EN Siri dili.
/// Niyet çalışınca ağ durumu loglanır; böylece "çevrimdışıyken çalıştı" kanıtlanır.
@main
struct SpikeHApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
            NetworkProbe.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike H · Siri internetsiz") {
                Section("İfadeler") {
                    Text("TR: \"Ses Ver başlat\", \"Ses Ver ile sinyal ver\", \"Ses Ver durdur\"\nEN: \"Start Ses Ver\", \"Stop Ses Ver\"")
                        .font(.footnote)
                    Button("Ağ durumunu logla") { NetworkProbe.shared.logNow(context: "manual") }
                }
            }
        }
    }
}

/// Ağ yolu durumu (Uçak Modu kanıtı).
@MainActor
final class NetworkProbe {
    static let shared = NetworkProbe()
    private let monitor = NWPathMonitor()
    private(set) var status = "unknown"

    func start() {
        monitor.pathUpdateHandler = { path in
            let s = "\(path.status)"
            let ifaces = path.availableInterfaces.map { "\($0.type)" }.joined(separator: ",")
            Task { @MainActor in
                NetworkProbe.shared.status = "\(s) [\(ifaces)]"
                SpikeLog.shared.log("network_path", [("status", s), ("interfaces", ifaces)])
            }
        }
        monitor.start(queue: DispatchQueue(label: "sesver.spike.h.net"))
    }

    func logNow(context: String) {
        SpikeLog.shared.log("network_status", [("context", context), ("status", status)])
    }
}

/// Siri ifadeleri. Geliştirme dili `tr`; İngilizce karşılıklar `en.lproj/AppShortcuts.strings` içinde.
struct SpikeHShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBeaconIntent(),
            phrases: [
                "\(.applicationName) başlat",
                "\(.applicationName) ile sinyal ver",
            ],
            shortTitle: "Sinyali başlat",
            systemImageName: "waveform")
        AppShortcut(
            intent: StopBeaconIntent(),
            phrases: ["\(.applicationName) durdur"],
            shortTitle: "Sinyali durdur",
            systemImageName: "stop.fill")
    }
}
