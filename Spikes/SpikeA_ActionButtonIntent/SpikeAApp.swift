import AppIntents
import SwiftUI

/// Spike (a): Eylem Düğmesi → `StartBeaconIntent` (AudioPlaybackIntent) kilitliyken ses başlatıyor mu?
@main
struct SpikeAApp: App {
    init() {
        MainActor.assumeIsolated {
            SystemObservers.install()
            RunMarker.markLaunch()
        }
    }

    var body: some Scene {
        WindowGroup {
            SpikeHarnessView(title: "Spike A · Eylem Düğmesi") {
                Section("Kurulum") {
                    Text("Ayarlar › Eylem Düğmesi › Kestirme › \"SV A\" › \"Sinyali başlat\". iOS 18+: Eylem Düğmesi › Denetimler ile Spike B kontrolü de denenebilir.")
                        .font(.footnote)
                }
            }
        }
    }
}

/// App Shortcut'lar Eylem Düğmesi ve Kestirmeler'de doğrudan seçilebilir.
struct SpikeAShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBeaconIntent(),
            phrases: ["\(.applicationName) sinyali başlat"],
            shortTitle: "Sinyali başlat",
            systemImageName: "waveform")
        AppShortcut(
            intent: StopBeaconIntent(),
            phrases: ["\(.applicationName) sinyali durdur"],
            shortTitle: "Sinyali durdur",
            systemImageName: "stop.fill")
    }
}
